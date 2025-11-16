require "rails_helper"

RSpec.describe "Api::V1::DataPackages", type: :request do
  let(:headers) { {"Accept" => "application/json", "Content-Type" => "application/json"} }
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/data_packages" do
    subject(:make_request) { get api_v1_data_packages_path, headers: headers, params: params }

    let(:params) { {} }

    context "success without filters" do
      let(:stream) { create(:data_stream) }
      let(:org) { create(:organization) }
      let!(:pkg1) { create(:data_package, :draft, data_stream: stream, sender_organization: org) }
      let!(:pkg2) { create(:data_package, :transmitted, data_stream: stream, sender_organization: org) }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns all data packages" do
        expect(json.size).to eq(2)
        expect(json).to match_array([
          hash_including("id" => pkg1.id, "state" => "draft"),
          hash_including("id" => pkg2.id, "state" => "transmitted")
        ])
      end

      it "returns flat JSON with correct structure" do
        expect(json.first).to match(
          "id" => pkg1.id,
          "data_stream_id" => pkg1.data_stream_id,
          "sender_organization_id" => pkg1.sender_organization_id,
          "state" => "draft",
          "title" => pkg1.title,
          "sent_at" => nil,
          "acknowledged_at" => nil,
          "created_at" => anything,
          "updated_at" => anything
        )
      end

      it_behaves_like "a paginated endpoint"
    end

    it_behaves_like "a paginated endpoint respecting page size"

    context "with state filter" do
      let!(:pkg_draft) { create(:data_package, :draft) }
      let!(:pkg_transmitted) { create(:data_package, :transmitted) }
      let!(:pkg_ack) { create(:data_package, :acknowledged) }
      let(:params) { {state: "draft,transmitted"} }

      before { make_request }

      it "returns only packages matching state filter" do
        expect(json.size).to eq(2)
        expect(json).to match_array([
          hash_including("id" => pkg_draft.id, "state" => "draft"),
          hash_including("id" => pkg_transmitted.id, "state" => "transmitted")
        ])
      end
    end

    context "with data_stream_id filter" do
      let(:stream1) { create(:data_stream) }
      let(:stream2) { create(:data_stream) }
      let!(:pkg1) { create(:data_package, data_stream: stream1) }
      let!(:pkg2) { create(:data_package, data_stream: stream2) }
      let(:params) { {data_stream_id: stream1.id} }

      before { make_request }

      it "returns only packages for specified stream" do
        expect(json.size).to eq(1)
        expect(json.first["id"]).to eq(pkg1.id)
      end
    end

    context "with combined filters" do
      let(:stream) { create(:data_stream) }
      let(:org) { create(:organization) }
      let!(:pkg1) { create(:data_package, :draft, data_stream: stream, sender_organization: org) }
      let!(:pkg2) { create(:data_package, :transmitted, data_stream: stream, sender_organization: org) }
      let!(:pkg3) { create(:data_package, :draft, sender_organization: org) }
      let(:params) { {state: "draft", data_stream_id: stream.id} }

      before { make_request }

      it "returns packages matching all filters" do
        expect(json.size).to eq(1)
        expect(json.first["id"]).to eq(pkg1.id)
      end
    end
  end

  describe "GET /api/v1/data_streams/:id/data_packages" do
    subject(:make_request) { get api_v1_data_stream_data_packages_path(id), headers: headers }

    let(:data_stream) { create(:data_stream) }
    let(:other_stream) { create(:data_stream) }
    let(:id) { data_stream.id }

    context "success" do
      let!(:pkg1) { create(:data_package, :draft, data_stream: data_stream) }
      let!(:pkg2) { create(:data_package, :transmitted, data_stream: data_stream) }
      let!(:pkg3) { create(:data_package, data_stream: other_stream) }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns only packages for this data stream" do
        expect(json.size).to eq(2)
        expect(json).to match_array([
          hash_including("id" => pkg1.id, "data_stream_id" => data_stream.id),
          hash_including("id" => pkg2.id, "data_stream_id" => data_stream.id)
        ])
      end
    end

    context "when data stream has no packages" do
      before { make_request }

      it "returns empty array" do
        expect(json).to eq([])
      end
    end
  end

  describe "GET /api/v1/data_packages/:id" do
    subject(:make_request) { get api_v1_data_package_path(id), headers: headers }

    context "when data package exists" do
      let(:data_package) { create(:data_package, :transmitted) }
      let(:id) { data_package.id }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns the data package" do
        expect(json).to match(
          "id" => data_package.id,
          "data_stream_id" => data_package.data_stream_id,
          "sender_organization_id" => data_package.sender_organization_id,
          "state" => "transmitted",
          "title" => data_package.title,
          "sent_at" => anything,
          "acknowledged_at" => nil,
          "created_at" => anything,
          "updated_at" => anything
        )
      end
    end

    context "when data package does not exist" do
      let(:id) { SecureRandom.uuid }

      before { make_request }

      it "returns 404 Not Found" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/data_streams/:id/data_packages" do
    subject(:make_request) { post api_v1_data_stream_data_packages_path(data_stream_id), headers: headers, params: params.to_json }

    let(:data_stream) { create(:data_stream, name: "CertDC") }
    let(:organization) { create(:organization) }
    let(:data_stream_id) { data_stream.id }

    context "with valid params and custom title" do
      let(:params) do
        {
          data_package: {
            sender_organization_id: organization.id,
            title: "Custom Package Title"
          }
        }
      end

      it "creates a new data package" do
        expect { make_request }.to change(DataPackage, :count).by(1)
      end

      it "returns 201 Created" do
        make_request
        expect(response).to have_http_status(:created)
      end

      it "returns the created data package with custom title" do
        make_request
        expect(json).to include(
          "state" => "draft",
          "title" => "Custom Package Title",
          "data_stream_id" => data_stream.id,
          "sender_organization_id" => organization.id
        )
      end
    end

    context "without title (auto-generated)" do
      let(:params) do
        {
          data_package: {
            sender_organization_id: organization.id
          }
        }
      end

      it "creates data package with auto-generated title" do
        make_request
        expect(json["title"]).to match(/\ACertDC-\d{8}-\d{6}-[A-Z0-9]{4}\z/)
      end
    end

    context "with invalid params" do
      let(:params) do
        {
          data_package: {
            sender_organization_id: nil
          }
        }
      end

      it "returns 422 Unprocessable Content" do
        make_request
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns validation errors" do
        make_request
        expect(json).to match(
          "sender_organization" => array_including("must exist")
        )
      end
    end
  end

  describe "DELETE /api/v1/data_packages/:id" do
    subject(:make_request) { delete api_v1_data_package_path(id), headers: headers }

    let(:id) { data_package.id }

    context "when data package is draft" do
      let(:data_package) { create(:data_package, :draft) }

      it "destroys the data package" do
        data_package
        expect { make_request }.to change(DataPackage, :count).by(-1)
      end

      it "returns 204 No Content" do
        make_request
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when data package is acknowledged" do
      let(:data_package) { create(:data_package, :acknowledged) }

      it "destroys the data package" do
        data_package
        expect { make_request }.to change(DataPackage, :count).by(-1)
      end

      it "returns 204 No Content" do
        make_request
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when data package is transmitted" do
      let(:data_package) { create(:data_package, :transmitted) }

      it "does not destroy the data package" do
        data_package
        expect { make_request }.not_to change(DataPackage, :count)
      end

      it "returns 422 Unprocessable Content" do
        make_request
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns error message" do
        make_request
        expect(json).to match(
          "base" => array_including("Cannot destroy data_package in state: transmitted")
        )
      end
    end
  end
end
