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

    it { is_expected.to validate_presence_of(:permission_type) }
    it { is_expected.to validate_uniqueness_of(:data_stream_id).scoped_to(:organization_id).ignoring_case_sensitivity }
  end

  describe "enum permission_type" do
    it { is_expected.to define_enum_for(:permission_type).with_values(read: "read", write: "write", read_write: "read_write").backed_by_column_of_type(:enum) }
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
