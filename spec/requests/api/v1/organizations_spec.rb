require "rails_helper"

RSpec.describe "Api::V1::Organizations", type: :request do
  let(:headers) { {"Accept" => "application/json", "Content-Type" => "application/json"} }
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/organizations" do
    subject(:make_request) { get api_v1_organizations_path, headers: headers }

    context "success" do
      let!(:org1) { create(:organization, name: "Org A", siret: "11111111111111") }
      let!(:org2) { create(:organization, name: "Org B", siret: "22222222222222") }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns all organizations" do
        expect(json).to match_array([
          hash_including("name" => "Org A", "siret" => "11111111111111", "created_at" => anything, "updated_at" => anything),
          hash_including("name" => "Org B", "siret" => "22222222222222", "created_at" => anything, "updated_at" => anything)
        ])
      end

      it "includes pagination headers" do
        expect(response.headers["X-Page"]).to eq("1")
        expect(response.headers["X-Per-Page"]).to eq(Pagy::DEFAULT[:limit].to_s)
      end
    end

    context "with many records" do
      let!(:organizations) { create_list(:organization, 60) }

      before { make_request }

      it "respects default page size from Pagy config" do
        expect(json.size).to eq(Pagy::DEFAULT[:limit])
      end
    end
  end

  describe "GET /api/v1/organizations/:id" do
    subject(:make_request) { get api_v1_organization_path(id), headers: headers }

    context "success" do
      let(:organization) { create(:organization, name: "DILA", siret: "12345678901234") }
      let(:id) { organization.id }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns organization data" do
        expect(json).to match(
          "id" => organization.id,
          "name" => "DILA",
          "siret" => "12345678901234",
          "created_at" => anything,
          "updated_at" => anything
        )
      end
    end

    context "not found" do
      let(:id) { SecureRandom.uuid }

      before { make_request }

      it "returns 404 Not Found" do
        expect(response).to have_http_status(:not_found)
      end

      it "returns error response" do
        expect(json).to match(
          "error" => "Not found"
        )
      end
    end
  end
end
