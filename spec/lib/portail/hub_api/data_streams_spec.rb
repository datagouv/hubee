# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::HubAPI::DataStreams do
  describe ".find" do
    it "translates the upstream data stream into a portal model" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_data_stream(build_v2_data_stream(code: "CERTDC"))

      data_stream = described_class.find(code: "CERTDC", client: client)

      expect(data_stream).to be_a(Portail::DataStream)
      expect(data_stream.code).to eq("CERTDC")
    end

    # Symbols en amont, String ici, dans l'ordre de l'amont : la liste entière, pas seulement
    # l'état qui varie, pour qu'une règle de plus arrive sans traduction à reprendre.
    it "lists the states the data stream allows in the portal vocabulary" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_data_stream(build_v2_data_stream(code: "CERTDC"))

      expect(described_class.find(code: "CERTDC", client: client).allowed_states)
        .to eq(%w[transmitted acknowledged in_progress awaiting_attachments done refused closed integration_error])
    end

    it "leaves out a state the data stream withholds" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_data_stream(build_v2_data_stream(code: "CERTDC",
        allowed_states: HubApiV1::V2::Mapping::ORDERED_STATES - [:awaiting_attachments]))

      expect(described_class.find(code: "CERTDC", client: client).allowed_states)
        .to eq(%w[transmitted acknowledged in_progress done refused closed integration_error])
    end

    it "keeps the name the upstream serves" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_data_stream(build_v2_data_stream(code: "CERTDC", name: "Certificat de décès électronique"))

      expect(described_class.find(code: "CERTDC", client: client).name).to eq("Certificat de décès électronique")
    end

    # L'amont sert `nil` quand il n'a pas de nom : le repli appartient à l'affichage, pas ici.
    it "keeps the absence of a name as an absence" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_data_stream(build_v2_data_stream(code: "CERTDC", name: nil))

      expect(described_class.find(code: "CERTDC", client: client).name).to be_nil
    end

    # Le faux client ne connaît que les flux déclarés : un code inconnu est rejoué comme l'amont
    # le refuse, traduction comprise.
    it "raises a not found error when the data stream is unknown upstream" do
      client = HubApiV1::Testing::FakeClient.new

      expect { described_class.find(code: "INCONNU", client: client) }.to raise_error(Portail::HubAPI::NotFound)
    end
  end

  describe ".fetch" do
    # Le cache de test est un `null_store` : sans vrai magasin, « lu une seule fois » passerait tout
    # seul et ne prouverait rien. Le magasin sérialise ce qu'il garde, comme celui de production.
    def with_a_real_cache
      expect(Rails).to receive(:cache).at_least(:once).and_return(ActiveSupport::Cache::MemoryStore.new)
    end

    it "reads a data stream" do
      client = use_hub_api_fake_client
      client.add_data_stream(build_v2_data_stream(code: "CERTDC"))

      expect(described_class.fetch("CERTDC").code).to eq("CERTDC")
    end

    # Le menu d'états et la validation de la cible le demandent tous deux dans la même requête :
    # une seule requête amont, et la relecture rend le flux entier, sérialisation comprise.
    it "reads the upstream only once for the same data stream" do
      with_a_real_cache
      client = use_hub_api_fake_client
      client.add_data_stream(build_v2_data_stream(code: "CERTDC"))

      first = described_class.fetch("CERTDC")
      second = described_class.fetch("CERTDC")

      expect(second).to eq(first)
      expect(client.requests.size).to eq(1)
    end

    # La clé porte la forme du flux : un membre ajouté met le cache précédent hors jeu sans
    # qu'on ait à y penser.
    it "namespaces its cache key by the shape of what it stores" do
      expect(described_class::CACHE_NAMESPACE).to end_with("code-name-allowed_states")
    end

    # Une heure : assez pour ne pas marteler l'amont, assez court pour qu'un paramétrage
    # changé se voie dans la journée.
    it "reads the upstream again once an hour has passed" do
      with_a_real_cache
      client = use_hub_api_fake_client
      client.add_data_stream(build_v2_data_stream(code: "CERTDC"))

      described_class.fetch("CERTDC")
      travel(59.minutes) { described_class.fetch("CERTDC") }
      travel(61.minutes) { described_class.fetch("CERTDC") }

      expect(client.requests.size).to eq(2)
    end

    it "reads the upstream again for another data stream" do
      with_a_real_cache
      client = use_hub_api_fake_client
      client.add_data_stream(build_v2_data_stream(code: "CERTDC"))
      client.add_data_stream(build_v2_data_stream(code: "AEC"))

      described_class.fetch("CERTDC")
      described_class.fetch("AEC")

      expect(client.requests.size).to eq(2)
    end

    # Une panne de transport, seul cas où la classe de la gem se bouchonne.
    it "returns nothing, logged, when the upstream is unavailable" do
      use_hub_api_fake_client
      expect(HubApiV1::V2::DataStream).to receive(:find).and_raise(HubApiV1::Client::ServerError)

      data_stream = nil
      events = capture_semantic_logger_events { data_stream = described_class.fetch("CERTDC") }

      expect(data_stream).to be_nil
      expect(events).to include(be_a_semantic_logger_event(level: :error, message_includes: "Flux indisponible"))
    end

    it "returns nothing when the data stream is unknown upstream" do
      use_hub_api_fake_client

      expect(described_class.fetch("INCONNU")).to be_nil
    end

    # Une lecture qui échoue ne se met pas en cache : la suivante retente, sinon une panne d'une
    # seconde priverait l'agent de son menu pendant une heure.
    it "does not remember a failure" do
      with_a_real_cache
      use_hub_api_fake_client
      expect(HubApiV1::V2::DataStream).to receive(:find).twice.and_raise(HubApiV1::Client::ServerError)

      2.times { described_class.fetch("CERTDC") }
    end
  end

  # Aucune exception de la gem ne doit survivre à cette couche. Seule la panne est signalée : un
  # refus de l'amont est une décision, pas un incident, et noyer la supervision les rendrait tous
  # invisibles.
  describe "error translation" do
    upstream_errors = {
      "a data stream the upstream does not know" => {
        raised: HubApiV1::V2::DataStreamNotFoundError, translated: Portail::HubAPI::NotFound,
        reported: false
      },
      "a code the upstream refuses" => {
        raised: HubApiV1::V2::InvalidArgumentError, translated: Portail::HubAPI::InvalidRequest,
        reported: false
      },
      # Le compte du portail n'est pas autorisé sur la route du référentiel : un incident
      # d'exploitation, pas une situation à expliquer à l'agent.
      "a configuration refusal" => {
        raised: HubApiV1::Client::ForbiddenError, translated: Portail::HubAPI::Unavailable,
        reported: true
      },
      "a transport failure" => {
        raised: HubApiV1::Client::Error, translated: Portail::HubAPI::Unavailable, reported: true
      },
      "an upstream error of any other family" => {
        raised: HubApiV1::Error, translated: Portail::HubAPI::Unavailable, reported: true
      }
    }

    upstream_errors.each do |situation, error|
      it "raises #{error[:translated].name.demodulize} for #{situation}, reported: #{error[:reported]}" do
        use_hub_api_fake_client
        expect(HubApiV1::V2::DataStream).to receive(:find).and_raise(error[:raised])
        if error[:reported]
          expect(Rails.error).to receive(:report).with(instance_of(error[:raised]), handled: true)
        else
          expect(Rails.error).not_to receive(:report)
        end

        expect { described_class.find(code: "CERTDC") }.to raise_error(error[:translated])
      end
    end
  end
end
