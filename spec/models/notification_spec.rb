# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notification, type: :model do
  it_behaves_like "a model with UUID v7 primary key"

  describe "associations" do
    it { is_expected.to belong_to(:data_package) }
    it { is_expected.to belong_to(:subscription) }
  end

  describe "validations" do
    subject { build(:notification) }

    it { is_expected.to validate_uniqueness_of(:subscription_id).scoped_to(:data_package_id).ignoring_case_sensitivity }
  end

  describe "database columns" do
    it { is_expected.to have_db_column(:data_package_id).of_type(:uuid).with_options(null: false) }
    it { is_expected.to have_db_column(:subscription_id).of_type(:uuid).with_options(null: false) }
    it { is_expected.to have_db_column(:acknowledged_at).of_type(:datetime) }
  end

  describe "database indexes" do
    it { is_expected.to have_db_index(:data_package_id) }
    it { is_expected.to have_db_index(:subscription_id) }
    it { is_expected.to have_db_index([:data_package_id, :subscription_id]).unique }
    it { is_expected.to have_db_index(:acknowledged_at) }
  end

  describe "#acknowledge!" do
    let(:notification) { create(:notification) }

    it "sets acknowledged_at to current time" do
      before_time = Time.current
      notification.acknowledge!
      after_time = Time.current
      notification.reload
      expect(notification.acknowledged_at).to be_between(before_time, after_time)
    end
  end

  describe "#acknowledged?" do
    it "returns false when acknowledged_at is nil" do
      notification = build(:notification, acknowledged_at: nil)
      expect(notification.acknowledged?).to be false
    end

    it "returns true when acknowledged_at is present" do
      notification = build(:notification, :acknowledged)
      expect(notification.acknowledged?).to be true
    end
  end

  describe ".transmitted" do
    let!(:transmitted_notification) { create(:notification, acknowledged_at: nil) }
    let!(:acknowledged_notification) { create(:notification, :acknowledged) }

    it "returns only notifications with nil acknowledged_at" do
      expect(Notification.transmitted).to contain_exactly(transmitted_notification)
    end
  end

  describe ".acknowledged" do
    let!(:transmitted_notification) { create(:notification, acknowledged_at: nil) }
    let!(:acknowledged_notification) { create(:notification, :acknowledged) }

    it "returns only notifications with present acknowledged_at" do
      expect(Notification.acknowledged).to contain_exactly(acknowledged_notification)
    end
  end
end
