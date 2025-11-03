require "rails_helper"

RSpec.describe DataStream, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:owner_organization).class_name("Organization") }
  end

  describe "validations" do
    subject { build(:data_stream) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:retention_days).is_greater_than(0).allow_nil }
  end

  describe "database constraints" do
    it "enforces foreign key constraint on owner_organization_id" do
      data_stream = build(:data_stream)
      data_stream.owner_organization_id = SecureRandom.uuid

      expect {
        data_stream.save(validate: false)
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "generates unique UUIDs for multiple records" do
      stream1 = create(:data_stream)
      stream2 = create(:data_stream)
      stream3 = create(:data_stream)

      expect(stream1.id).not_to eq(stream2.id)
      expect(stream1.id).not_to eq(stream3.id)
      expect(stream2.id).not_to eq(stream3.id)
    end
  end

  describe "uuid generation" do
    it "automatically generates a UUID v7 on creation" do
      data_stream = create(:data_stream)
      expect(data_stream.id).to be_present
      expect(data_stream.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
    end
  end

  describe "UUID v7 ordering" do
    let!(:stream1) { create(:data_stream, name: "First") }
    let!(:stream2) { create(:data_stream, name: "Second") }
    let!(:stream3) { create(:data_stream, name: "Third") }

    it "orders .first and .last chronologically by time-sortable UUID v7" do
      expect(DataStream.first).to eq(stream1)
      expect(DataStream.last).to eq(stream3)
    end
  end
end
