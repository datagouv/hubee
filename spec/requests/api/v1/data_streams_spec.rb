require "rails_helper"

RSpec.describe "Api::V1::DataStreams", type: :request do
  let(:headers) { {"Accept" => "application/json", "Content-Type" => "application/json"} }
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/data_streams" do
    subject(:make_request) { get api_v1_data_streams_path, headers: headers }

    context "success" do
      let!(:org1) { create(:organization) }
      let!(:org2) { create(:organization) }
      let!(:stream1) { create(:data_stream, owner_organization: org1) }
      let!(:stream2) { create(:data_stream, owner_organization: org2) }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns all data_streams" do
        expect(json).to match_array([
          hash_including("id" => stream1.uuid, "owner_organization_siret" => org1.siret, "name" => anything, "created_at" => anything, "updated_at" => anything),
          hash_including("id" => stream2.uuid, "owner_organization_siret" => org2.siret, "name" => anything, "created_at" => anything, "updated_at" => anything)
        ])
      end

      it "includes pagination headers" do
        expect(response.headers["X-Page"]).to eq("1")
        expect(response.headers["X-Per-Page"]).to eq(Pagy::DEFAULT[:limit].to_s)
      end
    end

    context "with many records" do
      let!(:organization) { create(:organization) }
      let!(:data_streams) { create_list(:data_stream, 60, owner_organization: organization) }

      before { make_request }

      it "respects default page size from Pagy config" do
        expect(json.size).to eq(Pagy::DEFAULT[:limit])
      end
    end
  end

  describe "GET /api/v1/data_streams/:uuid" do
    subject(:make_request) { get api_v1_data_stream_path(uuid), headers: headers }

    context "success" do
      let(:organization) { create(:organization, name: "DINUM", siret: "13002526500013") }
      let(:data_stream) { create(:data_stream, name: "CertDC", description: "Certificats", owner_organization: organization, retention_days: 365) }
      let(:uuid) { data_stream.uuid }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns data_stream data" do
        expect(json).to match(
          "id" => data_stream.uuid,
          "name" => "CertDC",
          "description" => "Certificats",
          "owner_organization_siret" => "13002526500013",
          "retention_days" => 365,
          "created_at" => anything,
          "updated_at" => anything
        )
      end
    end

    context "not found" do
      let(:uuid) { SecureRandom.uuid }

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

  describe "POST /api/v1/data_streams" do
    subject(:make_request) { post api_v1_data_streams_path, headers: headers, params: params.to_json }

    let(:organization) { create(:organization, siret: "13002526500013") }

    context "success" do
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

      it "creates a new data_stream" do
        expect { make_request }.to change(DataStream, :count).by(1)
      end

      it "returns 201 Created" do
        make_request
        expect(response).to have_http_status(:created)
      end

      it "creates data_stream and returns complete data" do
        make_request

        created = DataStream.last
        expect(created).to have_attributes(name: "CertDC", retention_days: 365)

        expect(json).to match(
          "id" => created.uuid,
          "name" => "CertDC",
          "description" => "Certificats de décès",
          "owner_organization_siret" => "13002526500013",
          "retention_days" => 365,
          "created_at" => anything,
          "updated_at" => anything
        )
      end
    end

    context "validation error" do
      let(:params) { {data_stream: {description: "Test", owner_organization_siret: organization.siret}} }

      before { make_request }

      it "does not create data_stream" do
        expect { make_request }.not_to change(DataStream, :count)
      end

      it "returns 422 Unprocessable Content" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns validation errors" do
        expect(json).to match(
          "name" => array_including("can't be blank")
        )
      end
    end
  end

  describe "PUT /api/v1/data_streams/:uuid" do
    let(:organization) { create(:organization) }
    let(:data_stream) { create(:data_stream, name: "Old Name", description: "Old Desc", owner_organization: organization, retention_days: 365) }
    subject(:make_request) { put api_v1_data_stream_path(data_stream.uuid), headers: headers, params: params.to_json }

    context "success" do
      let(:params) { {data_stream: {name: "Updated Name", retention_days: 180}} }

      it "returns 200 OK" do
        make_request
        expect(response).to have_http_status(:ok)
      end

      it "updates data_stream and returns complete data" do
        make_request

        expect(data_stream.reload).to have_attributes(name: "Updated Name", retention_days: 180)

        expect(json).to match(
          "id" => data_stream.uuid,
          "name" => "Updated Name",
          "description" => "Old Desc",
          "owner_organization_siret" => organization.siret,
          "retention_days" => 180,
          "created_at" => anything,
          "updated_at" => anything
        )
      end
    end

    context "validation error" do
      let(:params) { {data_stream: {name: "", retention_days: -5}} }

      before { make_request }

      it "returns 422 Unprocessable Content" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not update data_stream" do
        expect(data_stream.reload.name).to eq("Old Name")
      end

      it "returns validation errors" do
        expect(json).to match(
          "name" => array_including("can't be blank"),
          "retention_days" => array_including("must be greater than 0")
        )
      end
    end
  end

  describe "DELETE /api/v1/data_streams/:uuid" do
    let(:organization) { create(:organization) }
    let!(:data_stream) { create(:data_stream, owner_organization: organization) }
    subject(:make_request) { delete api_v1_data_stream_path(data_stream.uuid), headers: headers }

    it "deletes the data_stream" do
      expect { make_request }.to change(DataStream, :count).by(-1)
    end

    it "returns 204 No Content" do
      make_request
      expect(response).to have_http_status(:no_content)
    end
  end
end
