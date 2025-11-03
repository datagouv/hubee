# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:data_stream) }
    it { is_expected.to belong_to(:organization) }
  end

  describe "validations" do
    subject { build(:subscription) }

    it { is_expected.to validate_presence_of(:permission_type) }
    it { is_expected.to validate_uniqueness_of(:data_stream_id).scoped_to(:organization_id).ignoring_case_sensitivity }
  end

  describe "enum permission_type" do
    it "accepts valid permission_type values" do
      expect { create(:subscription, permission_type: "read") }.not_to raise_error
      expect { create(:subscription, permission_type: "write") }.not_to raise_error
      expect { create(:subscription, permission_type: "read_write") }.not_to raise_error
    end

    it "rejects invalid permission_type values" do
      subscription = create(:subscription)
      expect {
        subscription.update_column(:permission_type, "invalid")
      }.to raise_error(ActiveRecord::StatementInvalid, /invalid input value for enum permission_type/)
    end
  end

  describe "database constraints" do
    let(:subscription) { create(:subscription) }

    it "cascades delete when data_stream is destroyed" do
      data_stream = subscription.data_stream
      expect { data_stream.destroy! }.to change(Subscription, :count).by(-1)
    end

    it "cascades delete when organization is destroyed" do
      organization = subscription.organization
      expect { organization.destroy! }.to change(Subscription, :count).by(-1)
    end

    it "enforces unique constraint on data_stream_id and organization_id" do
      duplicate = build(:subscription, data_stream: subscription.data_stream, organization: subscription.organization)
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
  describe "UUID v7 ordering" do
    let!(:subscription1) { create(:subscription, :read_only) }
    let!(:subscription2) { create(:subscription, :write_only) }
    let!(:subscription3) { create(:subscription, :read_write) }

    it "orders .first and .last chronologically by time-sortable UUID v7" do
      expect(Subscription.first).to eq(subscription1)
      expect(Subscription.last).to eq(subscription3)
    end
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

  describe ".with_permission_types" do
    let!(:sub_read) { create(:subscription, :read_only) }
    let!(:sub_write) { create(:subscription, :write_only) }
    let!(:sub_read_write) { create(:subscription, :read_write) }

    it "filters by single permission type" do
      expect(Subscription.with_permission_types("read")).to contain_exactly(sub_read)
    end

    it "filters by multiple permission types as CSV" do
      expect(Subscription.with_permission_types("read,read_write")).to contain_exactly(sub_read, sub_read_write)
    end

    it "strips whitespace from CSV" do
      expect(Subscription.with_permission_types(" read , write ")).to contain_exactly(sub_read, sub_write)
    end

    it "ignores invalid permission types and keeps valid ones" do
      expect(Subscription.with_permission_types("invalid,read")).to contain_exactly(sub_read)
    end

    it "returns none when all types are invalid" do
      expect(Subscription.with_permission_types("invalid,unknown")).to be_empty
    end

    it "returns all when types is nil" do
      expect(Subscription.with_permission_types(nil)).to contain_exactly(sub_read, sub_write, sub_read_write)
    end

    it "returns all when types is not a string" do
      expect(Subscription.with_permission_types(["write", "read_write"])).to contain_exactly(sub_read, sub_write, sub_read_write)
    end
  end
end
