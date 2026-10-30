# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::HubAPI::DataStreams do
  describe ".verify" do
    # Le cache de test est un `null_store` : sans vrai magasin, « demandé une seule fois » ne prouverait rien.
    def with_a_real_cache
      expect(Rails).to receive(:cache).at_least(:once).and_return(ActiveSupport::Cache::MemoryStore.new)
    end

    it "accepts a data stream hub-api knows" do
      stub_hub_api_v2_data_stream(code: "CERTDC")

      expect(described_class.verify(code: "CERTDC")).to be(true)
    end

    it "says unknown a data stream hub-api does not know" do
      stub_hub_api_v2_data_stream_not_found(code: "INCONNU")

      expect { described_class.verify(code: "INCONNU") }.to raise_error(API::HubAPI::NotFound)
    end

    it "says unknown, keeps unverified and logs a code hub-api answers under another one" do
      with_a_real_cache
      expect(HubApiV1::V2::DataStream).to receive(:find).with(hash_including(code: "certdc")).twice
        .and_return(build_v2_data_stream(code: "CERTDC"))
      expect(Rails.logger).to receive(:warn).with("hub-api désigne « CERTDC » pour « certdc »").twice

      2.times do
        expect { described_class.verify(code: "certdc") }
          .to raise_error(API::HubAPI::NotFound, "hub-api désigne « CERTDC » pour « certdc »")
      end
    end

    {
      "a server error" => HubApiV1::Client::ServerError,
      "a timeout or a refused connection" => HubApiV1::Client::Error,
      "a missing right on the data streams" => HubApiV1::Client::ForbiddenError
    }.each do |failure, error|
      it "says unavailable on #{failure}, and reports it" do
        stub_hub_api_v2_data_stream_error(code: "CERTDC", error:)
        expect(Rails.error).to receive(:report).with(instance_of(error), handled: true)

        expect { described_class.verify(code: "CERTDC") }.to raise_error(API::HubAPI::Unavailable, /\A#{error.name} : /)
      end
    end

    it "says unknown a dot segment code, without asking hub-api" do
      client = HubApiV1::Testing::FakeClient.new

      [".", ".."].each do |code|
        expect { described_class.verify(code:, client:) }.to raise_error(API::HubAPI::NotFound, "code cannot be a dot segment")
      end
      expect(client.requests).to be_empty
    end

    it "rejects a blank code as a caller bug, neither unknown nor unavailable" do
      expect { described_class.verify(code: "", client: HubApiV1::Testing::FakeClient.new) }
        .to raise_error(ArgumentError, "code is required")
    end

    # L'import en parallèle porte souvent les mêmes codes : hub-api n'est pas sollicité à chaque agent.
    it "asks hub-api once an hour about a data stream it knows" do
      with_a_real_cache
      client = use_hub_api_fake_client
      client.add_data_stream(build_v2_data_stream(code: "CERTDC"))

      described_class.verify(code: "CERTDC")
      travel(59.minutes) { described_class.verify(code: "CERTDC") }
      travel(61.minutes) { described_class.verify(code: "CERTDC") }

      expect(client.requests.size).to eq(2)
    end

    it "asks hub-api again about a data stream it said unknown" do
      with_a_real_cache
      client = use_hub_api_fake_client

      2.times { expect { described_class.verify(code: "INCONNU") }.to raise_error(API::HubAPI::NotFound) }

      expect(client.requests.size).to eq(2)
    end

    # Une panne ne vaut jamais acceptation : le code reste à vérifier au prochain appel.
    it "asks hub-api again about a data stream it could not verify" do
      with_a_real_cache
      expect(HubApiV1::V2::DataStream).to receive(:find).twice.and_raise(HubApiV1::Client::ServerError)

      2.times { expect { described_class.verify(code: "CERTDC") }.to raise_error(API::HubAPI::Unavailable) }
    end
  end
end
