# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription, type: :model do
  it_behaves_like "a model with UUID v7 primary key"

  describe "associations" do
    it { is_expected.to belong_to(:data_stream) }
    it { is_expected.to belong_to(:organization) }
  end

  describe "validations" do
    subject { build(:subscription) }

    it { is_expected.to validate_uniqueness_of(:data_stream_id).scoped_to(:organization_id).ignoring_case_sensitivity }

    describe "at_least_one_permission" do
      it "is valid with can_read only" do
        subscription = build(:subscription, can_read: true, can_write: false)
        expect(subscription).to be_valid
      end

      it "is valid with can_write only" do
        subscription = build(:subscription, can_read: false, can_write: true)
        expect(subscription).to be_valid
      end

      it "is valid with both permissions" do
        subscription = build(:subscription, can_read: true, can_write: true)
        expect(subscription).to be_valid
      end

      it "is invalid with no permissions" do
        subscription = build(:subscription, can_read: false, can_write: false)
        expect(subscription).not_to be_valid
        expect(subscription.errors[:base]).to include("must have at least one permission (can_read or can_write)")
      end
    end
  end

  describe "database columns" do
    it { is_expected.to have_db_column(:can_read).of_type(:boolean).with_options(default: true, null: false) }
    it { is_expected.to have_db_column(:can_write).of_type(:boolean).with_options(default: false, null: false) }
  end

  describe "database indexes" do
    it { is_expected.to have_db_index(:data_stream_id) }
    it { is_expected.to have_db_index(:organization_id) }
    it { is_expected.to have_db_index([:data_stream_id, :organization_id]).unique }
  end

  describe ".by_data_stream" do
    let(:stream1) { create(:data_stream) }
    let(:stream2) { create(:data_stream) }
    let!(:sub1) { create(:subscription, data_stream: stream1) }
    let!(:sub2) { create(:subscription, data_stream: stream2) }

    it "filters by data_stream_id" do
      expect(Subscription.by_data_stream(stream1.id)).to contain_exactly(sub1)
    end

    it "returns all when id is nil" do
      expect(Subscription.by_data_stream(nil)).to contain_exactly(sub1, sub2)
    end
  end

  describe ".by_organization" do
    let(:org1) { create(:organization) }
    let(:org2) { create(:organization) }
    let!(:sub1) { create(:subscription, organization: org1) }
    let!(:sub2) { create(:subscription, organization: org2) }

    it "filters by organization_id" do
      expect(Subscription.by_organization(org1.id)).to contain_exactly(sub1)
    end

    it "returns all when id is nil" do
      expect(Subscription.by_organization(nil)).to contain_exactly(sub1, sub2)
    end
  end

  describe ".with_read_permission" do
    let!(:sub_read) { create(:subscription, :read_only) }
    let!(:sub_write) { create(:subscription, :write_only) }
    let!(:sub_read_write) { create(:subscription, :read_write) }

    it "returns subscriptions with can_read true" do
      expect(Subscription.with_read_permission).to contain_exactly(sub_read, sub_read_write)
    end
  end

  describe ".with_write_permission" do
    let!(:sub_read) { create(:subscription, :read_only) }
    let!(:sub_write) { create(:subscription, :write_only) }
    let!(:sub_read_write) { create(:subscription, :read_write) }

    it "returns subscriptions with can_write true" do
      expect(Subscription.with_write_permission).to contain_exactly(sub_write, sub_read_write)
    end
  end

  describe ".by_can_read" do
    it_behaves_like "a boolean filter scope", :by_can_read, :can_read
  end

  describe ".by_can_write" do
    it_behaves_like "a boolean filter scope", :by_can_write, :can_write
  end
end
