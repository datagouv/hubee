require "rails_helper"

RSpec.describe API::Referential::Organization do
  subject(:find_organization) { described_class.find(siret: siret, insee_code: "001") }

  let(:siret) { "21750056000016" }

  describe ".find" do
    it "translates a referential organization into the V2 vocabulary" do
      stub_hub_api_organization_found(
        siret: siret,
        type: "SI",
        branch_code: "001",
        record: build_organization_record(
          siret: siret, type: "SI", branch_code: "001", name: "Mairie de Paris 6e"
        )
      )

      expect(find_organization).to eq(
        described_class::Record.new(siret: siret, insee_code: "001", name: "Mairie de Paris 6e")
      )
    end

    it "looks the referential up under the SI type without the caller naming it" do
      stub_hub_api_organization_found(siret: siret, type: "SI", branch_code: "001")

      find_organization

      expect(HubApiV1::Organization).to have_received(:find)
        .with(hash_including(siret: siret, type: "SI", branch_code: "001"))
    end

    it "reports a triplet the referential does not know" do
      stub_hub_api_organization_not_found(siret: siret)

      expect { find_organization }.to raise_error(described_class::NotFound)
    end

    it "distinguishes a referential that violates its own key from one that did not respond" do
      stub_hub_api_organization_ambiguous(siret: siret)

      expect { find_organization }.to raise_error(described_class::Inconsistent)
    end

    it "reports a transport failure as unavailable" do
      stub_hub_api_organization_error(siret: siret, error: HubApiV1::Client::ServerError)

      expect { find_organization }.to raise_error(described_class::Unavailable)
    end

    it "keeps the referential error as the cause so the caller can tell what happened" do
      stub_hub_api_organization_error(siret: siret, error: HubApiV1::Client::ServerError)

      expect { find_organization }.to raise_error(described_class::Unavailable) { |error|
        expect(error.cause).to be_a(HubApiV1::Client::ServerError)
      }
    end

    # Un bug d'appelant ne se déguise pas en constat métier : on ne le rattrape pas.
    it "lets an argument bug propagate instead of dressing it up as a factual outcome" do
      allow(HubApiV1::Organization).to receive(:find).and_raise(HubApiV1::InvalidArgumentError)

      expect { find_organization }.to raise_error(HubApiV1::InvalidArgumentError)
    end
  end
end
