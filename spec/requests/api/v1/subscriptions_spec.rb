# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Subscriptions", type: :request do
  let(:headers) { {"Accept" => "application/json", "Content-Type" => "application/json"} }
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/organizations/:id/subscriptions" do
    subject(:make_request) { get api_v1_organization_subscriptions_path(id), headers: headers, params: params }

    let(:params) { {} }
    let(:pagination_factory_params) { {organization: organization} }

    context "success without filters" do
      let!(:organization) { create(:organization, siret: "13002526500013") }
      let!(:other_org) { create(:organization) }
      let!(:stream1) { create(:data_stream) }
      let!(:stream2) { create(:data_stream) }
      let!(:stream3) { create(:data_stream) }
      let!(:sub1) { create(:subscription, :read_only, data_stream: stream1, organization: organization) }
      let!(:sub2) { create(:subscription, :write_only, data_stream: stream2, organization: organization) }
      let!(:sub3) { create(:subscription, data_stream: stream3, organization: other_org) }
      let(:id) { organization.id }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns all subscriptions for this organization" do
        expect(json.size).to eq(2)
        expect(json).to match_array([
          hash_including("id" => sub1.id, "organization" => hash_including("id" => organization.id), "can_read" => true, "can_write" => false),
          hash_including("id" => sub2.id, "organization" => hash_including("id" => organization.id), "can_read" => false, "can_write" => true)
        ])
      end
    end

    context "with organization and permission filters combined" do
      let!(:organization) { create(:organization, siret: "13002526500013") }
      let!(:stream1) { create(:data_stream) }
      let!(:stream2) { create(:data_stream) }
      let!(:stream3) { create(:data_stream) }
      let!(:sub_read) { create(:subscription, :read_only, data_stream: stream1, organization: organization) }
      let!(:sub_write) { create(:subscription, :write_only, data_stream: stream2, organization: organization) }
      let!(:sub_read_write) { create(:subscription, :read_write, data_stream: stream3, organization: organization) }
      let(:id) { organization.id }
      let(:params) { {can_write: "true"} }

      before { make_request }

      it "returns only subscriptions matching both filters" do
        expect(json.size).to eq(2)
        expect(json).to match_array([
          hash_including("id" => sub_write.id, "can_read" => false, "can_write" => true),
          hash_including("id" => sub_read_write.id, "can_read" => true, "can_write" => true)
        ])
      end
    end

    it_behaves_like "a paginated endpoint respecting page size" do
      let!(:organization) { create(:organization) }
      let(:id) { organization.id }
    end
  end

  describe "GET /api/v1/data_streams/:id/subscriptions" do
    subject(:make_request) { get api_v1_data_stream_subscriptions_path(id), headers: headers, params: params }

    let(:params) { {} }

    context "success without filters" do
      let(:data_stream) { create(:data_stream) }
      let(:other_stream) { create(:data_stream) }
      let(:org1) { create(:organization) }
      let(:org2) { create(:organization) }
      let!(:sub1) { create(:subscription, :read_only, data_stream: data_stream, organization: org1) }
      let!(:sub2) { create(:subscription, :write_only, data_stream: data_stream, organization: org2) }
      let!(:sub3) { create(:subscription, data_stream: other_stream, organization: org1) }
      let(:id) { data_stream.id }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns all subscriptions for this data stream" do
        expect(json.size).to eq(2)
        expect(json).to match_array([
          hash_including("id" => sub1.id, "data_stream_id" => data_stream.id, "can_read" => true, "can_write" => false),
          hash_including("id" => sub2.id, "data_stream_id" => data_stream.id, "can_read" => false, "can_write" => true)
        ])
      end
    end

    context "with data_stream and permission filters combined" do
      let(:data_stream) { create(:data_stream) }
      let(:org1) { create(:organization) }
      let(:org2) { create(:organization) }
      let(:org3) { create(:organization) }
      let!(:sub_read) { create(:subscription, :read_only, data_stream: data_stream, organization: org1) }
      let!(:sub_write) { create(:subscription, :write_only, data_stream: data_stream, organization: org2) }
      let!(:sub_read_write) { create(:subscription, :read_write, data_stream: data_stream, organization: org3) }
      let(:id) { data_stream.id }
      let(:params) { {can_read: "true"} }

      before { make_request }

      it "returns only subscriptions matching both filters" do
        expect(json.size).to eq(2)
        expect(json).to match_array([
          hash_including("id" => sub_read.id, "can_read" => true, "can_write" => false),
          hash_including("id" => sub_read_write.id, "can_read" => true, "can_write" => true)
        ])
      end
    end
  end

  describe "GET /api/v1/subscriptions/:id" do
    subject(:make_request) { get api_v1_subscription_path(id), headers: headers }

    context "success" do
      let(:organization) { create(:organization, siret: "13002526500013") }
      let(:data_stream) { create(:data_stream, name: "CertDC") }
      let(:subscription) { create(:subscription, :read_write, data_stream: data_stream, organization: organization) }
      let(:id) { subscription.id }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns subscription data" do
        expect(json).to match(
          "id" => subscription.id,
          "data_stream_id" => data_stream.id,
          "organization" => hash_including("id" => organization.id, "name" => organization.name, "siret" => organization.siret),
          "can_read" => true,
          "can_write" => true,
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
        expect(json).to match("error" => "Not found")
      end
    end
  end

  describe "POST /api/v1/data_streams/:id/subscriptions" do
    subject(:make_request) { post api_v1_data_stream_subscriptions_path(data_stream.id), headers: headers, params: params.to_json }

    let(:data_stream) { create(:data_stream) }
    let(:organization) { create(:organization, siret: "13002526500013") }

    context "success" do
      let(:params) do
        {
          subscription: {
            organization_id: organization.id,
            can_read: true,
            can_write: true
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
        expect(created).to have_attributes(can_read: true, can_write: true)

        expect(json).to match(
          "id" => created.id,
          "data_stream_id" => data_stream.id,
          "organization" => hash_including("id" => organization.id, "name" => organization.name, "siret" => organization.siret),
          "can_read" => true,
          "can_write" => true,
          "created_at" => anything,
          "updated_at" => anything
        )
      end
    end

    context "validation error" do
      let(:params) { {subscription: {can_read: true, can_write: false}} }

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

  describe "PUT /api/v1/subscriptions/:id" do
    let(:organization) { create(:organization) }
    let(:data_stream) { create(:data_stream) }
    let(:subscription) { create(:subscription, :read_only, data_stream: data_stream, organization: organization) }
    subject(:make_request) { put api_v1_subscription_path(subscription.id), headers: headers, params: params.to_json }

    context "success" do
      let(:params) { {subscription: {can_read: true, can_write: true}} }

      it "returns 200 OK" do
        make_request
        expect(response).to have_http_status(:ok)
      end

      it "updates subscription and returns complete data" do
        make_request

        expect(subscription.reload).to have_attributes(can_read: true, can_write: true)

        expect(json).to match(
          "id" => subscription.id,
          "data_stream_id" => data_stream.id,
          "organization" => hash_including("id" => organization.id, "name" => organization.name, "siret" => organization.siret),
          "can_read" => true,
          "can_write" => true,
          "created_at" => anything,
          "updated_at" => anything
        )
      end
    end

    context "validation error" do
      let(:params) { {subscription: {can_read: false, can_write: false}} }

      before { make_request }

      it "returns 422 Unprocessable Content" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not update subscription" do
        expect(subscription.reload).to have_attributes(can_read: true, can_write: false)
      end

      it "returns validation errors" do
        expect(json).to match(
          "base" => array_including("must have at least one permission (can_read or can_write)")
        )
      end
    end
  end

  describe "DELETE /api/v1/subscriptions/:id" do
    let(:organization) { create(:organization) }
    let(:data_stream) { create(:data_stream) }
    let!(:subscription) { create(:subscription, data_stream: data_stream, organization: organization) }
    subject(:make_request) { delete api_v1_subscription_path(subscription.id), headers: headers }

    it "deletes the subscription" do
      expect { make_request }.to change(Subscription, :count).by(-1)
    end

    it "returns 204 No Content" do
      make_request
      expect(response).to have_http_status(:no_content)
    end
  end
end
