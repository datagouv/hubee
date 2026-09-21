# frozen_string_literal: true

require "rails_helper"

# La frontière avec la gem pour les abonnements d'une organisation.
RSpec.describe Portail::HubAPI::Subscriptions do
  let(:siret) { HubApiV1::Testing::Factories::DEFAULT_SIRET }
  let(:insee_code) { HubApiV1::Testing::Factories::DEFAULT_CODE_INSEE }

  describe ".list" do
    # Deux abonnements aux valeurs distinctes : une traduction qui recopierait le premier
    # passerait un test à un seul abonnement. Le mode d'accès arrive en Symbol et ressort en
    # String, comme l'état d'un télédossier.
    it "translates the upstream subscriptions into portal models" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_subscription(build_v2_subscription(access_mode: :portal,
        data_stream: HubApiV1::V2::DataStreamSummary.new(code: "CERTDC", name: "Certificat de décès électronique")))
      client.add_subscription(build_v2_subscription(id: "sub-2", access_mode: :api, read_package: false,
        data_stream: HubApiV1::V2::DataStreamSummary.new(code: "AEC", name: "Actes d'état civil")))

      list = described_class.list(siret: siret, insee_code: insee_code, client: client)

      expect(list).to be_a(Portail::Subscription::List)
      expect(list.subscriptions).to all(be_a(Portail::Subscription))
      expect(list.subscriptions.map { |subscription| subscription.data_stream.code }).to contain_exactly("CERTDC", "AEC")
      expect(list.subscriptions.find { |subscription| subscription.data_stream.code == "CERTDC" }).to have_attributes(
        id: "550e8400-e29b-41d4-a716-446655440000", data_stream_name: "Certificat de décès électronique",
        read_package: true, create_package: false, access_mode: "portal"
      )
      expect(list.subscriptions.find { |subscription| subscription.data_stream.code == "AEC" })
        .to have_attributes(data_stream_name: "Actes d'état civil", read_package: false, access_mode: "api")
    end

    # Un flux que l'amont ne nomme pas reste un abonnement entier : l'intitulé seul manque.
    it "leaves an unnamed data stream unnamed" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_subscription(build_v2_subscription(data_stream: HubApiV1::V2::DataStreamSummary.new(code: "CERTDC", name: nil)))

      list = described_class.list(siret: siret, insee_code: insee_code, client: client)

      expect(list.subscriptions.first).to have_attributes(data_stream_name: nil, read_package: true)
    end

    # Un canal non renseigné en amont reste inconnu ici : « » ferait croire à une valeur.
    it "leaves an unset access mode unknown" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_subscription(build_v2_subscription(access_mode: nil))

      list = described_class.list(siret: siret, insee_code: insee_code, client: client)

      expect(list.subscriptions.first).to have_attributes(read_package: true, access_mode: nil)
      expect(list.subscriptions.first).not_to be_readable_via_portal
    end

    # Hash complet : la lecture doit rester bornée sur le couple, pas sur le seul SIRET.
    it "sends the portal vocabulary as the upstream keywords" do
      client = HubApiV1::Testing::FakeClient.new
      expect(HubApiV1::V2::Subscription).to receive(:list)
        .with(siret: siret, code_insee: insee_code, client: client).and_return([])

      described_class.list(siret: siret, insee_code: insee_code, client: client)
    end

    it "hands the gem its shared client when none is injected" do
      shared = use_hub_api_fake_client
      expect(HubApiV1::V2::Subscription).to receive(:list)
        .with(siret: siret, code_insee: insee_code, client: shared).and_return([])

      described_class.list(siret: siret, insee_code: insee_code)
    end

    # Même politique que les télédossiers : une panne est un incident signalé, un refus non.
    it "raises Unavailable, reported, on a transport failure" do
      use_hub_api_fake_client
      expect(HubApiV1::V2::Subscription).to receive(:list).and_raise(HubApiV1::Client::ServerError)
      expect(Rails.error).to receive(:report).with(instance_of(HubApiV1::Client::ServerError), handled: true)

      expect {
        described_class.list(siret: siret, insee_code: insee_code)
      }.to raise_error(Portail::HubAPI::Unavailable)
    end

    it "raises InvalidRequest, not reported, on an argument the upstream refuses" do
      use_hub_api_fake_client
      expect(HubApiV1::V2::Subscription).to receive(:list).and_raise(HubApiV1::V2::InvalidArgumentError)
      expect(Rails.error).not_to receive(:report)

      expect {
        described_class.list(siret: siret, insee_code: insee_code)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
    end
  end

  describe ".fetch" do
    # Le cache de test est un `null_store` : sans vrai magasin, « lu une seule fois » passerait tout
    # seul et ne prouverait rien. Le magasin sérialise ce qu'il garde, comme celui de production.
    def with_a_real_cache
      expect(Rails).to receive(:cache).at_least(:once).and_return(ActiveSupport::Cache::MemoryStore.new)
    end

    it "reads the subscriptions of an organisation" do
      client = use_hub_api_fake_client
      client.add_subscription(build_v2_subscription)

      list = described_class.fetch(siret: siret, insee_code: insee_code)

      expect(list).to be_a(Portail::Subscription::List)
      expect(list.subscriptions.map { |subscription| subscription.data_stream.code }).to eq(["CERTDC"])
    end

    # Un appel par structure et par dix minutes, pour les flux proposés comme pour leurs noms, et
    # la relecture rend la liste entière, sérialisation comprise.
    it "reads the upstream once per organisation for ten minutes" do
      with_a_real_cache
      client = use_hub_api_fake_client
      client.add_subscription(build_v2_subscription)
      client.add_subscription(build_v2_subscription(id: "sub-2",
        organization: build_v2_recipient(siret: "13002526500013", code_insee: "75056")))

      first = described_class.fetch(siret: siret, insee_code: insee_code)
      second = described_class.fetch(siret: siret, insee_code: insee_code)
      described_class.fetch(siret: "13002526500013", insee_code: "75056")
      travel(9.minutes) { described_class.fetch(siret: siret, insee_code: insee_code) }

      expect(second).to eq(first)
      expect(client.requests.size).to eq(2)
    end

    it "reads the upstream again once ten minutes have passed" do
      with_a_real_cache
      client = use_hub_api_fake_client
      client.add_subscription(build_v2_subscription)

      described_class.fetch(siret: siret, insee_code: insee_code)
      travel(11.minutes) { described_class.fetch(siret: siret, insee_code: insee_code) }

      expect(client.requests.size).to eq(2)
    end

    # La clé porte la forme d'un abonnement : un membre ajouté met le cache précédent hors jeu.
    it "namespaces its cache key by the shape of what it stores" do
      expect(described_class::CACHE_NAMESPACE)
        .to end_with("id-data_stream-data_stream_name-read_package-create_package-access_mode")
    end

    # Une panne de transport, seul cas où la classe de la gem se bouchonne : déjà signalée par la
    # traduction, il ne reste qu'à journaliser et à laisser l'appelant décider.
    it "returns nothing, logged, when the upstream is unavailable" do
      use_hub_api_fake_client
      expect(HubApiV1::V2::Subscription).to receive(:list).and_raise(HubApiV1::Client::ServerError)

      list = nil
      events = capture_semantic_logger_events do
        list = described_class.fetch(siret: siret, insee_code: insee_code)
      end

      expect(list).to be_nil
      expect(events).to include(be_a_semantic_logger_event(level: :error, message_includes: "Abonnements indisponibles"))
    end

    # Une lecture qui échoue ne se met pas en cache : la suivante retente.
    it "does not remember a failure" do
      with_a_real_cache
      use_hub_api_fake_client
      expect(HubApiV1::V2::Subscription).to receive(:list).twice.and_raise(HubApiV1::Client::ServerError)

      2.times { described_class.fetch(siret: siret, insee_code: insee_code) }
    end
  end
end
