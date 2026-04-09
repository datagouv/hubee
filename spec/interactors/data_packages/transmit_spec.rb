# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataPackages::Transmit do
  describe ".call" do
    let(:data_stream) { create(:data_stream) }
    let(:sender_org) { create(:organization) }
    let(:data_package) { create(:data_package, :draft, data_stream: data_stream, sender_organization: sender_org) }

    subject(:result) { described_class.call(data_package: data_package) }

    context "with valid transmission" do
      let(:org1) { create(:organization, siret: "13002526500013") }
      let(:org2) { create(:organization, siret: "11000601200010") }
      let!(:sub1) { create(:subscription, data_stream: data_stream, organization: org1, can_read: true) }
      let!(:sub2) { create(:subscription, data_stream: data_stream, organization: org2, can_read: true) }

      before do
        data_package.update!(delivery_criteria: {"siret" => ["13002526500013", "11000601200010"]})
        allow(data_package).to receive(:has_completed_attachments?).and_return(true)
      end

      it "succeeds" do
        expect(result).to be_success
      end

      it "creates notifications for each targeted subscription" do
        expect { result }.to change(Notification, :count).by(2)
      end

      it "associates notifications with correct subscriptions" do
        result
        expect(data_package.notifications.pluck(:subscription_id)).to contain_exactly(sub1.id, sub2.id)
      end

      it "transitions to transmitted state" do
        result
        expect(data_package.reload.state).to eq("transmitted")
      end

      it "sets sent_at timestamp" do
        result
        expect(data_package.reload.sent_at).to be_present
      end

      it "provides target subscriptions in context" do
        expect(result.target_subscriptions).to be_present
      end
    end

    context "when package is not draft" do
      let(:data_package) { create(:data_package, :transmitted, data_stream: data_stream, sender_organization: sender_org) }

      it "fails" do
        expect(result).to be_failure
      end

      it "returns not_draft error" do
        expect(result.error).to eq(:not_draft)
      end

      it "does not create notifications" do
        expect { result }.not_to change(Notification, :count)
      end
    end

    context "when no completed attachments" do
      let(:org) { create(:organization, siret: "13002526500013") }
      let!(:subscription) { create(:subscription, data_stream: data_stream, organization: org, can_read: true) }

      before do
        data_package.update!(delivery_criteria: {"siret" => "13002526500013"})
        allow(data_package).to receive(:has_completed_attachments?).and_return(false)
      end

      it "fails" do
        expect(result).to be_failure
      end

      it "returns no_completed_attachments error" do
        expect(result.error).to eq(:no_completed_attachments)
      end

      it "does not create notifications" do
        expect { result }.not_to change(Notification, :count)
      end
    end

    context "when no recipient subscriptions" do
      before do
        data_package.update!(delivery_criteria: {"siret" => "99999999999999"})
        allow(data_package).to receive(:has_completed_attachments?).and_return(true)
      end

      it "fails" do
        expect(result).to be_failure
      end

      it "returns no_recipients error" do
        expect(result.error).to eq(:no_recipients)
      end

      it "does not create notifications" do
        expect { result }.not_to change(Notification, :count)
      end

      it "does not transition state" do
        result
        expect(data_package.reload.state).to eq("draft")
      end
    end

    context "when delivery criteria is nil" do
      before do
        data_package.update!(delivery_criteria: nil)
        allow(data_package).to receive(:has_completed_attachments?).and_return(true)
      end

      it "fails with no_recipients error" do
        expect(result).to be_failure
        expect(result.error).to eq(:no_recipients)
      end
    end

    context "when delivery criteria is empty" do
      before do
        data_package.update!(delivery_criteria: {})
        allow(data_package).to receive(:has_completed_attachments?).and_return(true)
      end

      it "fails with no_recipients error" do
        expect(result).to be_failure
        expect(result.error).to eq(:no_recipients)
      end
    end

    context "when criteria matches only can_write subscriptions" do
      let(:org) { create(:organization, siret: "13002526500013") }
      let!(:subscription) { create(:subscription, data_stream: data_stream, organization: org, can_read: false, can_write: true) }

      before do
        data_package.update!(delivery_criteria: {"siret" => "13002526500013"})
        allow(data_package).to receive(:has_completed_attachments?).and_return(true)
      end

      it "fails (only can_read subscriptions targeted)" do
        expect(result).to be_failure
        expect(result.error).to eq(:no_recipients)
      end
    end
  end
end
