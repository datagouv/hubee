require "rails_helper"

RSpec.describe "Api::V1::DataStreams", type: :request do
  let(:headers) { {"Accept" => "application/json", "Content-Type" => "application/json"} }
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/data_streams" do
    subject(:make_request) { get api_v1_data_streams_path, headers: headers, params: params }
    let(:params) { {} }

    context "when data_streams exist" do
      let!(:org1) { create(:organization) }
      let!(:org2) { create(:organization) }
      let!(:stream1) { create(:data_stream, owner_organization: org1) }
      let!(:stream2) { create(:data_stream, owner_organization: org2) }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns all data_streams as JSON array" do
        expect(json).to be_an(Array)
        expect(json.size).to eq(2)
        expect(json.map { |s| s["id"] }).to contain_exactly(stream1.uuid, stream2.uuid)
      end

      it "includes all required attributes" do
        stream_json = json.first

        expect(stream_json).to have_key("id")
        expect(stream_json).to have_key("name")
        expect(stream_json).to have_key("description")
        expect(stream_json).to have_key("owner_organization_id")
        expect(stream_json).to have_key("retention_days")
        expect(stream_json).to have_key("created_at")
      end

      it "exposes UUID as id" do
        stream_json = json.find { |s| s["id"] == stream1.uuid }
        expect(stream_json["id"]).to eq(stream1.uuid)
      end

      it "exposes owner_organization as SIRET" do
        stream_json = json.find { |s| s["id"] == stream1.uuid }
        expect(stream_json["owner_organization_id"]).to eq(org1.siret)
      end

      it "does not include excluded attributes" do
        stream_json = json.first
        expect(stream_json).not_to have_key("updated_at")
        expect(stream_json).not_to have_key("owner_organization")
      end

      it "includes pagination headers" do
        expect(response.headers["X-Page"]).to eq("1")
        expect(response.headers["X-Per-Page"]).to eq("50")
        expect(response.headers["X-Total"]).to eq("2")
        expect(response.headers["X-Total-Pages"]).to eq("1")
      end
    end

    context "when no data_streams exist" do
      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns empty array" do
        expect(json).to eq([])
      end
    end
  end

  describe "GET /api/v1/data_streams/:uuid" do
    subject(:make_request) { get api_v1_data_stream_path(stream_uuid), headers: headers }

    context "when data_stream exists" do
      let(:organization) { create(:organization, name: "DINUM", siret: "13002526500013") }
      let(:data_stream) { create(:data_stream, name: "CertDC", owner_organization: organization, retention_days: 365) }
      let(:stream_uuid) { data_stream.uuid }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns the data_stream as JSON object" do
        expect(json["id"]).to eq(data_stream.uuid)
        expect(json["name"]).to eq("CertDC")
        expect(json["retention_days"]).to eq(365)
      end

      it "includes all required attributes" do
        expect(json).to have_key("id")
        expect(json).to have_key("name")
        expect(json).to have_key("description")
        expect(json).to have_key("owner_organization_id")
        expect(json).to have_key("retention_days")
        expect(json).to have_key("created_at")
      end

      it "exposes owner_organization as SIRET" do
        expect(json["owner_organization_id"]).to eq("13002526500013")
      end

      it "does not nest the response in a wrapper key" do
        expect(json).not_to have_key("data_stream")
        expect(json).to have_key("id")
      end
    end

    context "when data_stream does not exist" do
      let(:stream_uuid) { SecureRandom.uuid }

      before { make_request }

      it "returns 404 Not Found" do
        expect(response).to have_http_status(:not_found)
      end

      it "returns JSON error response" do
        expect(response.content_type).to match(%r{application/json})
        expect(json).to have_key("error")
        expect(json["error"]).to eq("Not found")
      end
    end
  end

  describe "POST /api/v1/data_streams" do
    subject(:make_request) { post api_v1_data_streams_path, headers: headers, params: params.to_json }

    let(:organization) { create(:organization, siret: "13002526500013") }

    context "with valid parameters" do
      let(:params) do
        {
          data_stream: {
            name: "CertDC",
            description: "Certificats de décès",
            owner_organization_siret: organization.siret,
            retention_days: 365
          }
        }
      end

      it "returns 201 Created" do
        make_request
        expect(response).to have_http_status(:created)
      end

      it "creates a new data_stream" do
        expect { make_request }.to change(DataStream, :count).by(1)
      end

      it "returns the created data_stream" do
        make_request

        expect(json["id"]).to be_present
        expect(json["name"]).to eq("CertDC")
        expect(json["description"]).to eq("Certificats de décès")
        expect(json["retention_days"]).to eq(365)
        expect(json["owner_organization_id"]).to eq("13002526500013")
      end

      it "generates a UUID" do
        make_request
        expect(json["id"]).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end
    end

    context "with missing name" do
      let(:params) do
        {
          data_stream: {
            description: "Test",
            owner_organization_siret: organization.siret
          }
        }
      end

      it "returns 422 Unprocessable Entity" do
        make_request
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns validation errors" do
        make_request

        expect(json).to have_key("name")
        expect(json["name"]).to include("can't be blank")
      end
    end

    context "with invalid owner_organization_siret" do
      let(:params) do
        {
          data_stream: {
            name: "Test Stream",
            owner_organization_siret: "99999999999999"
          }
        }
      end

      it "returns 422 Unprocessable Entity" do
        make_request
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with invalid retention_days" do
      let(:params) do
        {
          data_stream: {
            name: "Test Stream",
            owner_organization_siret: organization.siret,
            retention_days: -10
          }
        }
      end

      it "returns 422 Unprocessable Entity" do
        make_request
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns validation errors" do
        make_request
        expect(json["retention_days"]).to include("must be greater than 0")
      end
    end

    context "with nil retention_days" do
      let(:params) do
        {
          data_stream: {
            name: "Test Stream",
            owner_organization_siret: organization.siret,
            retention_days: nil
          }
        }
      end

      it "returns 201 Created" do
        make_request
        expect(response).to have_http_status(:created)
      end

      it "creates the data_stream with nil retention_days" do
        make_request
        expect(json["retention_days"]).to be_nil
      end
    end

    context "with zero retention_days" do
      let(:params) do
        {
          data_stream: {
            name: "Test Stream",
            owner_organization_siret: organization.siret,
            retention_days: 0
          }
        }
      end

      it "returns 422 Unprocessable Entity" do
        make_request
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns validation errors" do
        make_request
        expect(json["retention_days"]).to include("must be greater than 0")
      end
    end
  end

  describe "PUT /api/v1/data_streams/:uuid" do
    subject(:make_request) { put api_v1_data_stream_path(stream_uuid), headers: headers, params: params.to_json }

    let(:organization) { create(:organization) }
    let(:data_stream) { create(:data_stream, name: "Old Name", owner_organization: organization) }
    let(:stream_uuid) { data_stream.uuid }

    context "with valid parameters" do
      let(:params) do
        {
          data_stream: {
            name: "Updated Name",
            description: "Updated description",
            retention_days: 180
          }
        }
      end

      it "returns 200 OK" do
        make_request
        expect(response).to have_http_status(:ok)
      end

      it "updates the data_stream" do
        make_request
        data_stream.reload

        expect(data_stream.name).to eq("Updated Name")
        expect(data_stream.description).to eq("Updated description")
        expect(data_stream.retention_days).to eq(180)
      end

      it "returns the updated data_stream" do
        make_request

        expect(json["id"]).to eq(data_stream.uuid)
        expect(json["name"]).to eq("Updated Name")
        expect(json["retention_days"]).to eq(180)
      end
    end

    context "with invalid parameters" do
      let(:params) do
        {
          data_stream: {
            name: "",
            retention_days: -5
          }
        }
      end

      it "returns 422 Unprocessable Entity" do
        make_request
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns validation errors" do
        make_request

        expect(json["name"]).to include("can't be blank")
        expect(json["retention_days"]).to include("must be greater than 0")
      end
    end

    context "when data_stream does not exist" do
      let(:stream_uuid) { SecureRandom.uuid }
      let(:params) { {data_stream: {name: "Test"}} }

      it "returns 404 Not Found" do
        make_request
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when updating owner_organization" do
      let(:new_organization) { create(:organization, siret: "98765432100034") }
      let(:params) do
        {
          data_stream: {
            owner_organization_siret: new_organization.siret
          }
        }
      end

      it "returns 200 OK" do
        make_request
        expect(response).to have_http_status(:ok)
      end

      it "updates the owner_organization" do
        make_request
        data_stream.reload

        expect(data_stream.owner_organization_id).to eq(new_organization.id)
        expect(json["owner_organization_id"]).to eq(new_organization.siret)
      end
    end
  end

  describe "DELETE /api/v1/data_streams/:uuid" do
    subject(:make_request) { delete api_v1_data_stream_path(stream_uuid), headers: headers }

    let(:organization) { create(:organization) }
    let!(:data_stream) { create(:data_stream, owner_organization: organization) }
    let(:stream_uuid) { data_stream.uuid }

    it "returns 204 No Content" do
      make_request
      expect(response).to have_http_status(:no_content)
    end

    it "deletes the data_stream" do
      expect { make_request }.to change(DataStream, :count).by(-1)
    end

    it "returns empty body" do
      make_request
      expect(response.body).to be_empty
    end

    context "when data_stream does not exist" do
      let(:stream_uuid) { SecureRandom.uuid }

      it "returns 404 Not Found" do
        make_request
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
