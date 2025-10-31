# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Subscriptions", type: :request do
  let(:headers) { {"Accept" => "application/json", "Content-Type" => "application/json"} }
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/organizations/:siret/subscriptions" do
    subject(:make_request) { get api_v1_organization_subscriptions_path(siret), headers: headers }

    context "success" do
      let!(:organization) { create(:organization, siret: "13002526500013") }
      let!(:other_org) { create(:organization) }
      let!(:stream1) { create(:data_stream) }
      let!(:stream2) { create(:data_stream) }
      let!(:stream3) { create(:data_stream) }
      let!(:sub1) { create(:subscription, :read_only, data_stream: stream1, organization: organization) }
      let!(:sub2) { create(:subscription, :write_only, data_stream: stream2, organization: organization) }
      let!(:sub3) { create(:subscription, data_stream: stream3, organization: other_org) }
      let(:siret) { organization.siret }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns only subscriptions for this organization" do
        expect(json.size).to eq(2)
        expect(json).to match_array([
          hash_including("id" => sub1.uuid, "organization_id" => organization.siret),
          hash_including("id" => sub2.uuid, "organization_id" => organization.siret)
        ])
      end
    end

    context "not found" do
      let(:siret) { "99999999999999" }

      it "returns 404 Not Found" do
        make_request
        expect(response).to have_http_status(:not_found)
      end

      it "returns error response" do
        make_request
        expect(json).to match("error" => "Not found")
      end
    end
  end

  describe "GET /api/v1/data_streams/:uuid/subscriptions" do
    subject(:make_request) { get api_v1_data_stream_subscriptions_path(uuid), headers: headers, params: params }

    let(:params) { {} }

    context "success" do
      let(:data_stream) { create(:data_stream) }
      let(:other_stream) { create(:data_stream) }
      let(:org1) { create(:organization) }
      let(:org2) { create(:organization) }
      let!(:sub1) { create(:subscription, :read_only, data_stream: data_stream, organization: org1) }
      let!(:sub2) { create(:subscription, :write_only, data_stream: data_stream, organization: org2) }
      let!(:sub3) { create(:subscription, data_stream: other_stream, organization: org1) }
      let(:uuid) { data_stream.uuid }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns only subscriptions for this data stream" do
        expect(json.size).to eq(2)
        expect(json).to match_array([
          hash_including("id" => sub1.uuid, "data_stream_id" => data_stream.uuid, "permission_type" => "read"),
          hash_including("id" => sub2.uuid, "data_stream_id" => data_stream.uuid, "permission_type" => "write")
        ])
      end
    end

    context "with permission_type filter for read and read_write" do
      let(:data_stream) { create(:data_stream) }
      let(:org1) { create(:organization) }
      let(:org2) { create(:organization) }
      let(:org3) { create(:organization) }
      let!(:sub_read) { create(:subscription, :read_only, data_stream: data_stream, organization: org1) }
      let!(:sub_write) { create(:subscription, :write_only, data_stream: data_stream, organization: org2) }
      let!(:sub_read_write) { create(:subscription, :read_write, data_stream: data_stream, organization: org3) }
      let(:uuid) { data_stream.uuid }
      let(:params) { {permission_type: "read,read_write"} }

      before { make_request }

      it "returns only subscriptions with read or read_write permission" do
        expect(json.size).to eq(2)
        expect(json).to match_array([
          hash_including("id" => sub_read.uuid, "permission_type" => "read"),
          hash_including("id" => sub_read_write.uuid, "permission_type" => "read_write")
        ])
      end
    end

    context "with permission_type filter for write and read_write" do
      let(:data_stream) { create(:data_stream) }
      let(:org1) { create(:organization) }
      let(:org2) { create(:organization) }
      let(:org3) { create(:organization) }
      let!(:sub_read) { create(:subscription, :read_only, data_stream: data_stream, organization: org1) }
      let!(:sub_write) { create(:subscription, :write_only, data_stream: data_stream, organization: org2) }
      let!(:sub_read_write) { create(:subscription, :read_write, data_stream: data_stream, organization: org3) }
      let(:uuid) { data_stream.uuid }
      let(:params) { {permission_type: "write,read_write"} }

      before { make_request }

      it "returns only subscriptions with write or read_write permission" do
        expect(json.size).to eq(2)
        expect(json).to match_array([
          hash_including("id" => sub_write.uuid, "permission_type" => "write"),
          hash_including("id" => sub_read_write.uuid, "permission_type" => "read_write")
        ])
      end
    end

    context "with permission_type filter for read_write only" do
      let(:data_stream) { create(:data_stream) }
      let(:org1) { create(:organization) }
      let(:org2) { create(:organization) }
      let(:org3) { create(:organization) }
      let!(:sub_read) { create(:subscription, :read_only, data_stream: data_stream, organization: org1) }
      let!(:sub_write) { create(:subscription, :write_only, data_stream: data_stream, organization: org2) }
      let!(:sub_read_write) { create(:subscription, :read_write, data_stream: data_stream, organization: org3) }
      let(:uuid) { data_stream.uuid }
      let(:params) { {permission_type: "read_write"} }

      before { make_request }

      it "returns only subscriptions with read_write permission" do
        expect(json.size).to eq(1)
        expect(json).to match_array([
          hash_including("id" => sub_read_write.uuid, "permission_type" => "read_write")
        ])
      end
    end

    context "with permission_type filter for read only" do
      let(:data_stream) { create(:data_stream) }
      let(:org1) { create(:organization) }
      let(:org2) { create(:organization) }
      let(:org3) { create(:organization) }
      let!(:sub_read) { create(:subscription, :read_only, data_stream: data_stream, organization: org1) }
      let!(:sub_write) { create(:subscription, :write_only, data_stream: data_stream, organization: org2) }
      let!(:sub_read_write) { create(:subscription, :read_write, data_stream: data_stream, organization: org3) }
      let(:uuid) { data_stream.uuid }
      let(:params) { {permission_type: "read"} }

      before { make_request }

      it "returns only subscriptions with read permission" do
        expect(json.size).to eq(1)
        expect(json).to match_array([
          hash_including("id" => sub_read.uuid, "permission_type" => "read")
        ])
      end
    end

    context "not found" do
      let(:uuid) { SecureRandom.uuid }

      before { make_request }

      it "returns 404 Not Found" do
        expect(response).to have_http_status(:not_found)
      end

      it "returns error response" do
        expect(json).to match("error" => "Not found")
      end
    end
  end

  describe "GET /api/v1/subscriptions/:uuid" do
    subject(:make_request) { get api_v1_subscription_path(uuid), headers: headers }

    context "success" do
      let(:organization) { create(:organization, siret: "13002526500013") }
      let(:data_stream) { create(:data_stream, name: "CertDC") }
      let(:subscription) { create(:subscription, :read_write, data_stream: data_stream, organization: organization) }
      let(:uuid) { subscription.uuid }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns subscription data" do
        expect(json).to match(
          "id" => subscription.uuid,
          "data_stream_id" => data_stream.uuid,
          "organization_id" => organization.siret,
          "permission_type" => "read_write",
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
        expect(json).to match("error" => "Not found")
      end
    end
  end

  describe "POST /api/v1/data_streams/:uuid/subscriptions" do
    subject(:make_request) { post api_v1_data_stream_subscriptions_path(data_stream.uuid), headers: headers, params: params.to_json }

    let(:data_stream) { create(:data_stream) }
    let(:organization) { create(:organization, siret: "13002526500013") }

    context "success" do
      let(:params) do
        {
          subscription: {
            organization_id: organization.siret,
            permission_type: "read_write"
          }
        }
      end

      it "creates a new subscription" do
        expect { make_request }.to change(Subscription, :count).by(1)
      end

      it "returns 201 Created" do
        make_request
        expect(response).to have_http_status(:created)
      end

      it "creates subscription and returns complete data" do
        make_request
        created = Subscription.last
        expect(created).to have_attributes(permission_type: "read_write")

        expect(json).to match(
          "id" => created.uuid,
          "data_stream_id" => data_stream.uuid,
          "organization_id" => organization.siret,
          "permission_type" => "read_write",
          "created_at" => anything,
          "updated_at" => anything
        )
      end
    end

    context "validation error" do
      let(:params) { {subscription: {permission_type: "read_write"}} }

      it "does not create subscription" do
        expect { make_request }.not_to change(Subscription, :count)
      end

      it "returns 422 Unprocessable Content" do
        make_request
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns validation errors" do
        make_request
        expect(json).to match(
          "organization" => array_including("must exist")
        )
      end
    end
  end

  describe "PUT /api/v1/subscriptions/:uuid" do
    let(:organization) { create(:organization) }
    let(:data_stream) { create(:data_stream) }
    let(:subscription) { create(:subscription, :read_only, data_stream: data_stream, organization: organization) }
    subject(:make_request) { put api_v1_subscription_path(subscription.uuid), headers: headers, params: params.to_json }

    context "success" do
      let(:params) { {subscription: {permission_type: "read_write"}} }

      it "returns 200 OK" do
        make_request
        expect(response).to have_http_status(:ok)
      end

      it "updates subscription and returns complete data" do
        make_request

        expect(subscription.reload).to have_attributes(permission_type: "read_write")

        expect(json).to match(
          "id" => subscription.uuid,
          "data_stream_id" => data_stream.uuid,
          "organization_id" => organization.siret,
          "permission_type" => "read_write",
          "created_at" => anything,
          "updated_at" => anything
        )
      end
    end

    context "validation error" do
      let(:params) { {subscription: {permission_type: ""}} }

      before { make_request }

      it "returns 422 Unprocessable Content" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not update subscription" do
        expect(subscription.reload.permission_type).to eq("read")
      end

      it "returns validation errors" do
        expect(json).to match(
          "permission_type" => array_including("can't be blank")
        )
      end
    end
  end

  describe "DELETE /api/v1/subscriptions/:uuid" do
    let(:organization) { create(:organization) }
    let(:data_stream) { create(:data_stream) }
    let!(:subscription) { create(:subscription, data_stream: data_stream, organization: organization) }
    subject(:make_request) { delete api_v1_subscription_path(subscription.uuid), headers: headers }

    it "deletes the subscription" do
      expect { make_request }.to change(Subscription, :count).by(-1)
    end

    it "returns 204 No Content" do
      make_request
      expect(response).to have_http_status(:no_content)
    end
  end
end
