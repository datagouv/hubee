# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::DataPackages::Subscriptions", type: :request do
  let(:headers) { {"Accept" => "application/json", "Content-Type" => "application/json"} }
  let(:json) { response.parsed_body }

  describe "GET /api/v1/data_packages/:data_package_id/subscriptions" do
    subject(:make_request) { get api_v1_data_package_subscriptions_path(data_package_id), headers: headers }

    let(:data_stream) { create(:data_stream) }
    let(:sender_org) { create(:organization) }
    let(:data_package) { create(:data_package, :draft, data_stream: data_stream, sender_organization: sender_org) }
    let(:data_package_id) { data_package.id }

    context "when package is draft with valid criteria" do
      let(:org1) { create(:organization, siret: "13002526500013", name: "Mairie de Vannes") }
      let(:org2) { create(:organization, siret: "11000601200010", name: "Préfecture Morbihan") }
      let!(:sub1) { create(:subscription, data_stream: data_stream, organization: org1, can_read: true) }
      let!(:sub2) { create(:subscription, data_stream: data_stream, organization: org2, can_read: true) }

      before do
        data_package.update!(delivery_criteria: {"siret" => ["13002526500013", "11000601200010"]})
        make_request
      end

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns subscriptions that would be targeted" do
        expect(json["subscriptions"]).to match_array([
          hash_including(
            "id" => sub1.id,
            "can_read" => true,
            "can_write" => false,
            "organization" => hash_including(
              "id" => org1.id,
              "name" => "Mairie de Vannes",
              "siret" => "13002526500013"
            )
          ),
          hash_including(
            "id" => sub2.id,
            "can_read" => true,
            "can_write" => false,
            "organization" => hash_including(
              "id" => org2.id,
              "name" => "Préfecture Morbihan",
              "siret" => "11000601200010"
            )
          )
        ])
      end

      it "echoes back the delivery_criteria" do
        expect(json["delivery_criteria"]).to eq({"siret" => ["13002526500013", "11000601200010"]})
      end

      it "indicates source is resolver (preview mode)" do
        expect(json["source"]).to eq("resolver")
      end
    end

    context "when package is transmitted (uses notifications)" do
      let(:org1) { create(:organization, siret: "13002526500013") }
      let(:org2) { create(:organization, siret: "11000601200010") }
      let!(:sub1) { create(:subscription, data_stream: data_stream, organization: org1, can_read: true) }
      let!(:sub2) { create(:subscription, data_stream: data_stream, organization: org2, can_read: true) }
      let(:transmitted_package) { create(:data_package, :transmitted, data_stream: data_stream, sender_organization: sender_org) }
      let(:data_package_id) { transmitted_package.id }

      before do
        # Create notifications for this transmitted package
        create(:notification, data_package: transmitted_package, subscription: sub1)
        create(:notification, data_package: transmitted_package, subscription: sub2)
        make_request
      end

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns subscriptions from notifications" do
        subscription_ids = json["subscriptions"].pluck("id")
        expect(subscription_ids).to contain_exactly(sub1.id, sub2.id)
      end

      it "indicates source is notifications" do
        expect(json["source"]).to eq("notifications")
      end

      it "includes organization nested in each subscription" do
        subscription = json["subscriptions"].first
        expect(subscription).to have_key("organization")
        expect(subscription["organization"]).to have_key("id")
        expect(subscription["organization"]).to have_key("name")
        expect(subscription["organization"]).to have_key("siret")
      end
    end

    context "when package is acknowledged (uses notifications)" do
      let(:org) { create(:organization) }
      let!(:sub) { create(:subscription, data_stream: data_stream, organization: org, can_read: true) }
      let(:acknowledged_package) { create(:data_package, :acknowledged, data_stream: data_stream, sender_organization: sender_org) }
      let(:data_package_id) { acknowledged_package.id }

      before do
        create(:notification, :acknowledged, data_package: acknowledged_package, subscription: sub)
        make_request
      end

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns subscriptions from notifications" do
        expect(json["subscriptions"].size).to eq(1)
        expect(json["subscriptions"].first["id"]).to eq(sub.id)
      end

      it "indicates source is notifications" do
        expect(json["source"]).to eq("notifications")
      end
    end

    context "when package has no delivery_criteria (draft)" do
      before do
        data_package.update!(delivery_criteria: nil)
        make_request
      end

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns empty subscriptions array" do
        expect(json["subscriptions"]).to eq([])
      end
    end

    context "when package has empty delivery_criteria" do
      before do
        data_package.update!(delivery_criteria: {})
        make_request
      end

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns empty subscriptions array" do
        expect(json["subscriptions"]).to eq([])
      end
    end

    context "when criteria match subscriptions without can_read" do
      let(:org) { create(:organization, siret: "13002526500013") }
      let!(:subscription) { create(:subscription, data_stream: data_stream, organization: org, can_read: false, can_write: true) }

      before do
        data_package.update!(delivery_criteria: {"siret" => "13002526500013"})
        make_request
      end

      it "returns empty subscriptions (only can_read subscriptions are targeted)" do
        expect(json["subscriptions"]).to eq([])
      end
    end

    context "when package does not exist" do
      let(:data_package_id) { SecureRandom.uuid }

      before { make_request }

      it "returns 404 Not Found" do
        expect(response).to have_http_status(:not_found)
      end

      it "returns error message" do
        expect(json["error"]).to eq("Not found")
      end
    end

    context "with complex criteria using _or operator" do
      let(:org1) { create(:organization, siret: "13002526500013") }
      let(:org2) { create(:organization, siret: "11000601200010") }
      let!(:sub1) { create(:subscription, data_stream: data_stream, organization: org1, can_read: true) }
      let!(:sub2) { create(:subscription, data_stream: data_stream, organization: org2, can_read: true) }

      before do
        data_package.update!(
          delivery_criteria: {
            "_or" => [
              {"siret" => "13002526500013"},
              {"organization_id" => org2.id}
            ]
          }
        )
        make_request
      end

      it "returns union of matched subscriptions" do
        sub_ids = json["subscriptions"].pluck("id")
        expect(sub_ids).to contain_exactly(sub1.id, sub2.id)
      end
    end

    context "with invalid criteria (draft package)" do
      before do
        # Bypass validation to test runtime error handling
        data_package.update_column(:delivery_criteria, {"unknown_field" => "value"})
        make_request
      end

      it "returns 422 Unprocessable Content" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns error details" do
        expect(json["error"]).to include("unsupported")
      end
    end

    context "with many records (pagination)" do
      let(:total_records) { 60 }

      before do
        # Create many subscriptions
        total_records.times do |i|
          org = create(:organization, siret: format("1300252650%04d", i + 100))
          create(:subscription, data_stream: data_stream, organization: org, can_read: true)
        end
        # Update criteria to match all SIRETs
        all_sirets = Subscription.where(data_stream: data_stream, can_read: true)
          .joins(:organization)
          .pluck("organizations.siret")
        data_package.update!(delivery_criteria: {"siret" => all_sirets})
        make_request
      end

      it "respects default page size from Pagy config" do
        expect(json["subscriptions"].size).to eq(Pagy.options[:limit])
      end

      it_behaves_like "a paginated endpoint"
    end
  end
end
