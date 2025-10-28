require "rails_helper"

RSpec.describe "Api::V1::Organizations", type: :request do
  let(:headers) { {"Accept" => "application/json", "Content-Type" => "application/json"} }
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/organizations" do
    subject(:make_request) { get api_v1_organizations_path, headers: headers, params: params }
    let(:params) { {} }

    context "when organizations exist" do
      let!(:org1) { create(:organization) }
      let!(:org2) { create(:organization) }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns all organizations as JSON array (Rails scaffold style)" do
        expect(json).to be_an(Array)
        expect(json.size).to eq(2)
        expect(json.map { |o| o["siret"] }).to contain_exactly(org1.siret, org2.siret)
      end

      it "includes all required attributes" do
        org_json = json.first

        expect(org_json).to have_key("name")
        expect(org_json).to have_key("siret")
        expect(org_json).to have_key("created_at")
      end

      it "does not expose internal id" do
        org_json = json.first
        expect(org_json).not_to have_key("id")
      end

      it "does not include excluded attributes" do
        org_json = json.first

        expect(org_json).not_to have_key("updated_at")
      end

      it "includes pagination headers" do
        expect(response.headers["X-Page"]).to eq("1")
        expect(response.headers["X-Per-Page"]).to eq("50")
        expect(response.headers["X-Total"]).to eq("2")
        expect(response.headers["X-Total-Pages"]).to eq("1")
      end
    end

    context "when no organizations exist" do
      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns empty array" do
        expect(json).to eq([])
      end

      it "includes pagination headers with zero count" do
        expect(response.headers["X-Page"]).to eq("1")
        expect(response.headers["X-Total"]).to eq("0")
      end
    end

    context "with pagination parameters" do
      let!(:organizations) { create_list(:organization, 60) }

      context "when requesting page 1 with default per_page" do
        let(:params) { {page: 1} }

        before { make_request }

        it "returns first 50 organizations" do
          expect(json.size).to eq(50)
        end

        it "sets correct pagination headers" do
          expect(response.headers["X-Page"]).to eq("1")
          expect(response.headers["X-Per-Page"]).to eq("50")
          expect(response.headers["X-Total"]).to eq("60")
          expect(response.headers["X-Total-Pages"]).to eq("2")
        end
      end

      context "when requesting page 2" do
        let(:params) { {page: 2} }

        before { make_request }

        it "returns remaining 10 organizations" do
          expect(json.size).to eq(10)
        end

        it "sets correct pagination headers" do
          expect(response.headers["X-Page"]).to eq("2")
          expect(response.headers["X-Per-Page"]).to eq("50")
          expect(response.headers["X-Total"]).to eq("60")
          expect(response.headers["X-Total-Pages"]).to eq("2")
        end
      end

      context "when requesting custom per_page" do
        let(:params) { {page: 1, per_page: 20} }

        before { make_request }

        it "returns requested number of organizations" do
          expect(json.size).to eq(20)
        end

        it "sets correct pagination headers" do
          expect(response.headers["X-Page"]).to eq("1")
          expect(response.headers["X-Per-Page"]).to eq("20")
          expect(response.headers["X-Total"]).to eq("60")
          expect(response.headers["X-Total-Pages"]).to eq("3")
        end
      end

      context "when requesting more than max allowed per_page" do
        let(:params) { {page: 1, per_page: 150} }

        before { make_request }

        it "limits to max 100 organizations" do
          expect(json.size).to eq(60) # Only 60 exist, but max would be 100
        end

        it "sets per_page to maximum allowed" do
          expect(response.headers["X-Per-Page"]).to eq("100")
        end
      end
    end
  end

  describe "GET /api/v1/organizations/:siret" do
    subject(:make_request) { get api_v1_organization_path(organization_siret), headers: headers }

    context "when organization exists" do
      let(:organization) { create(:organization, name: "DILA", siret: "11122233300001") }
      let(:organization_siret) { organization.siret }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns the organization as JSON object (Rails scaffold style)" do
        expect(json["name"]).to eq("DILA")
        expect(json["siret"]).to eq("11122233300001")
      end

      it "includes all required attributes" do
        expect(json).to have_key("name")
        expect(json).to have_key("siret")
        expect(json).to have_key("created_at")
      end

      it "does not expose internal id" do
        expect(json).not_to have_key("id")
      end

      it "does not include excluded attributes" do
        expect(json).not_to have_key("updated_at")
      end

      it "does not nest the response in a wrapper key" do
        # Direct object, not wrapped in "organization" key
        expect(json).not_to have_key("organization")
        expect(json).to have_key("siret")
      end
    end

    context "when organization does not exist" do
      let(:organization_siret) { "99999999999999" }

      before { make_request }

      it "returns 404 Not Found" do
        expect(response).to have_http_status(:not_found)
      end

      it "returns JSON error response" do
        expect(response.content_type).to match(%r{application/json})

        expect(json).to have_key("error")
        expect(json["error"]).to eq("Not Found")
      end
    end
  end

  describe "GET /api/v1/organizations (pagination edge cases)" do
    subject(:make_request) { get api_v1_organizations_path, headers: headers, params: params }

    context "when requesting page beyond available data" do
      let!(:organizations) { create_list(:organization, 10) }
      let(:params) { {page: 999} }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns empty array" do
        expect(json).to eq([])
      end

      it "sets pagination headers correctly" do
        expect(response.headers["X-Page"]).to eq("999")
        expect(response.headers["X-Total"]).to eq("10")
        expect(response.headers["X-Total-Pages"]).to eq("1")
      end
    end
  end
end
