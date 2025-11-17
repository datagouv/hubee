require "rails_helper"

RSpec.describe "Api::V1::Transmissions", type: :request do
  let(:headers) { {"Accept" => "application/json", "Content-Type" => "application/json"} }
  let(:json) { JSON.parse(response.body) }

  describe "POST /api/v1/data_packages/:data_package_id/transmission" do
    subject(:make_request) { post api_v1_data_package_transmission_path(data_package_id), headers: headers }

    let(:data_stream) { create(:data_stream) }
    let(:sender_org) { create(:organization) }
    let(:data_package) { create(:data_package, :draft, data_stream: data_stream, sender_organization: sender_org) }
    let(:data_package_id) { data_package.id }

    context "when data package can be sent" do
      let(:recipient_org) { create(:organization, siret: "13002526500013") }
      let!(:subscription) { create(:subscription, data_stream: data_stream, organization: recipient_org, can_read: true) }

      before do
        data_package.update!(delivery_criteria: {"siret" => "13002526500013"})
        allow_any_instance_of(DataPackage).to receive(:has_completed_attachments?).and_return(true)
      end

      it "transitions to transmitted status" do
        make_request
        expect(data_package.reload).to have_state(:transmitted)
        expect(data_package.reload.sent_at).to be_present
      end

      it "sets sent_at timestamp" do
        make_request
        expect(data_package.reload.sent_at).to be_present
      end

      it "creates notifications for targeted subscriptions" do
        expect { make_request }.to change(Notification, :count).by(1)
        expect(data_package.reload.notifications.first.subscription).to eq(subscription)
      end

      it "returns 200 OK" do
        make_request
        expect(response).to have_http_status(:ok)
      end

      it "returns the updated data package" do
        make_request
        expect(json).to match(
          hash_including(
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
        )
      end
    end

    context "when data package cannot be sent (not draft)" do
      let(:data_package) { create(:data_package, :transmitted) }

      before do
        allow_any_instance_of(DataPackage).to receive(:has_completed_attachments?).and_return(true)
      end

      it "does not change status" do
        expect { make_request }.not_to change { data_package.reload.state }
      end

      it "returns 422 Unprocessable Content" do
        make_request
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns error message" do
        make_request
        expect(json).to match(
          "state" => array_including("must be draft")
        )
      end
    end

    context "when data package cannot be sent (no completed attachments)" do
      before do
        allow_any_instance_of(DataPackage).to receive(:has_completed_attachments?).and_return(false)
      end

      it "returns 422 Unprocessable Content" do
        make_request
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns error message" do
        make_request
        expect(json).to match(
          "state" => array_including("must have completed attachments")
        )
      end
    end

    context "when data package has no recipient subscriptions" do
      before do
        data_package.update!(delivery_criteria: {"siret" => "99999999999999"})
        allow_any_instance_of(DataPackage).to receive(:has_completed_attachments?).and_return(true)
      end

      it "returns 422 Unprocessable Content" do
        make_request
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns error message about missing recipients" do
        make_request
        expect(json).to match(
          "base" => array_including("must have at least one recipient subscription")
        )
      end

      it "does not create any notifications" do
        expect { make_request }.not_to change(Notification, :count)
      end
    end
  end
end
