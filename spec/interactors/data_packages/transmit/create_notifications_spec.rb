# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataPackages::Transmit::CreateNotifications do
  describe ".call" do
    let(:data_stream) { create(:data_stream) }
    let(:data_package) { create(:data_package, :draft, data_stream: data_stream) }
    let(:org1) { create(:organization) }
    let(:org2) { create(:organization) }
    let!(:sub1) { create(:subscription, data_stream: data_stream, organization: org1, can_read: true) }
    let!(:sub2) { create(:subscription, data_stream: data_stream, organization: org2, can_read: true) }
    let(:target_subscriptions) { Subscription.where(id: [sub1.id, sub2.id]) }

    subject(:result) { described_class.call(data_package: data_package, target_subscriptions: target_subscriptions) }

    it { is_expected.to be_success }

    it "creates notifications for each subscription" do
      expect { result }.to change(Notification, :count).by(2)
    end

    it "associates notifications with correct subscriptions" do
      result
      expect(data_package.notifications.pluck(:subscription_id)).to contain_exactly(sub1.id, sub2.id)
    end
  end

  describe "#rollback" do
    let(:data_stream) { create(:data_stream) }
    let(:data_package) { create(:data_package, :draft, data_stream: data_stream) }
    let(:org) { create(:organization) }
    let!(:subscription) { create(:subscription, data_stream: data_stream, organization: org, can_read: true) }
    let(:target_subscriptions) { Subscription.where(id: subscription.id) }

    it "destroys created notifications on rollback" do
      context = described_class.call(data_package: data_package, target_subscriptions: target_subscriptions)
      expect(data_package.notifications.count).to eq(1)

      interactor = described_class.new(context)
      interactor.rollback

      expect(data_package.notifications.count).to eq(0)
    end
  end
end
