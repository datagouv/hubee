# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::HubAPI::DataStreams do
  describe ".find" do
    it "translates the upstream profile into a portal model" do
      stub_hub_api_v2_data_stream_profile(code: "CERTDC")

      profile = described_class.find(code: "CERTDC")

      expect(profile).to be_a(Portail::DataStream::Profile)
      expect(profile.code).to eq("CERTDC")
    end

    it "says a data stream allows awaiting documents" do
      stub_hub_api_v2_data_stream_profile(
        code: "CERTDC",
        profile: build_v2_data_stream_profile(code: "CERTDC", awaiting_documents: :allowed)
      )

      expect(described_class.find(code: "CERTDC")).to be_awaiting_documents_allowed
    end

    it "says a data stream forbids awaiting documents" do
      stub_hub_api_v2_data_stream_profile(
        code: "CERTDC",
        profile: build_v2_data_stream_profile(code: "CERTDC", awaiting_documents: :denied)
      )

      expect(described_class.find(code: "CERTDC")).not_to be_awaiting_documents_allowed
    end

    # Une démarche jamais configurée ne se prend pas pour une démarche permissive.
    it "does not take an unconfigured data stream for a permissive one" do
      stub_hub_api_v2_data_stream_profile(
        code: "CERTDC",
        profile: build_v2_data_stream_profile(code: "CERTDC", awaiting_documents: :unspecified)
      )

      expect(described_class.find(code: "CERTDC")).not_to be_awaiting_documents_allowed
    end

    it "keeps the name the upstream serves" do
      stub_hub_api_v2_data_stream_profile(
        code: "CERTDC",
        profile: build_v2_data_stream_profile(code: "CERTDC", name: "Certificat de décès électronique")
      )

      expect(described_class.find(code: "CERTDC").name).to eq("Certificat de décès électronique")
    end

    # L'amont sert `nil` quand il n'a pas de nom : le repli appartient à l'affichage, pas ici.
    it "keeps the absence of a name as an absence" do
      stub_hub_api_v2_data_stream_profile(
        code: "CERTDC",
        profile: build_v2_data_stream_profile(code: "CERTDC", name: nil)
      )

      expect(described_class.find(code: "CERTDC").name).to be_nil
    end

    it "raises a not found error when the data stream is unknown upstream" do
      stub_hub_api_v2_data_stream_profile_not_found(code: "INCONNU")

      expect { described_class.find(code: "INCONNU") }.to raise_error(Portail::HubAPI::NotFound)
    end

    it "raises an invalid request error when the code is blank" do
      expect { described_class.find(code: "") }.to raise_error(Portail::HubAPI::InvalidRequest)
    end

    it "raises an unavailable error when the upstream fails" do
      stub_hub_api_v2_data_stream_profile_error(code: "CERTDC", status: 500, response_body: "boom")

      expect { described_class.find(code: "CERTDC") }.to raise_error(Portail::HubAPI::Unavailable)
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
        expect(HubApiV1::V2::DataStreamProfile).to receive(:find).and_raise(error[:raised])
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
