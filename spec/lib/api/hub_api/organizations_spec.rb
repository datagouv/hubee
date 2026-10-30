# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::HubAPI::Organizations do
  describe ".verify" do
    it "confirms an SI organization designated by its SIRET and insee code" do
      stub_hub_api_organization_found(siret: "21750001600019", type: "SI", branch_code: "75056")

      expect(described_class.verify(siret: "21750001600019", insee_code: "75056")).to be(true)
    end

    # Le faux client traverse la vraie sélection de la gem : le référentiel ne filtre pas le code
    # de branche, c'est la gem qui le fait.
    it "tells apart two organizations sharing a SIRET by their insee code" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_organization(build_organization_record(siret: "21750001600019", type: "SI", branch_code: "75056"))
      client.add_organization(build_organization_record(siret: "21750001600019", type: "SI", branch_code: "75101"))

      expect(described_class.verify(siret: "21750001600019", insee_code: "75056", client: client)).to be(true)
      expect(described_class.verify(siret: "21750001600019", insee_code: "75101", client: client)).to be(true)
      expect { described_class.verify(siret: "21750001600019", insee_code: "13055", client: client) }
        .to raise_error(API::HubAPI::NotFound)
    end

    it "says unknown a known SIRET designated with an insee code it does not carry" do
      use_hub_api_fake_client.add_organization(
        build_organization_record(siret: "21750001600019", type: "SI", branch_code: "75056")
      )

      expect { described_class.verify(siret: "21750001600019", insee_code: "13055") }
        .to raise_error(API::HubAPI::NotFound)
    end

    it "says unknown an organization absent from the referential" do
      stub_hub_api_organization_not_found(siret: "21750001600019")

      expect { described_class.verify(siret: "21750001600019", insee_code: "75056") }
        .to raise_error(API::HubAPI::NotFound)
    end

    it "says unknown an organization the referential only knows under another type than SI" do
      use_hub_api_fake_client.add_organization(
        build_organization_record(siret: "21750001600019", type: "OSL", branch_code: "75056")
      )

      expect { described_class.verify(siret: "21750001600019", insee_code: "75056") }
        .to raise_error(API::HubAPI::NotFound)
    end

    # La V1 ne lit jamais ce statut en texte libre, la V2 non plus.
    it "confirms an organization whatever its status" do
      use_hub_api_fake_client.add_organization(
        build_organization_record(siret: "21750001600019", type: "SI", branch_code: "75056", status: "Fermée")
      )

      expect(described_class.verify(siret: "21750001600019", insee_code: "75056")).to be(true)
    end

    it "rejects a blank insee code as a caller bug, neither unknown nor unavailable" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_organization(build_organization_record(siret: "21750001600019", type: "SI", branch_code: "75056"))

      expect { described_class.verify(siret: "21750001600019", insee_code: "", client: client) }
        .to raise_error(ArgumentError, "branch_code is required")
    end

    it "says unavailable and reports a referential that returns several organizations" do
      stub_hub_api_organization_ambiguous(siret: "21750001600019")
      expect(Rails.error).to receive(:report).with(instance_of(HubApiV1::AmbiguousOrganizationError), handled: true)

      expect { described_class.verify(siret: "21750001600019", insee_code: "75056") }
        .to raise_error(API::HubAPI::Unavailable, /\AHubApiV1::AmbiguousOrganizationError : /)
    end

    # Le droit refusé compte : un client V1 de la V2 privé de la liste des organisations ne doit
    # pas les faire passer pour inconnues. Une route absente non plus : seule la gem dit « inconnue ».
    {
      "a server error" => HubApiV1::Client::ServerError,
      "a missing route on the referential" => HubApiV1::Client::NotFoundError,
      "a timeout or a refused connection" => HubApiV1::Client::Error,
      "a missing right on the organizations list" => HubApiV1::Client::ForbiddenError,
      "a rejected V2 client" => HubApiV1::Client::UnauthorizedError
    }.each do |failure, error|
      it "says unavailable on #{failure}, and reports it" do
        stub_hub_api_organization_error(siret: "21750001600019", error: error)
        expect(Rails.error).to receive(:report).with(instance_of(error), handled: true)

        expect { described_class.verify(siret: "21750001600019", insee_code: "75056") }
          .to raise_error(API::HubAPI::Unavailable, /\A#{error.name} : /)
      end
    end
  end
end
