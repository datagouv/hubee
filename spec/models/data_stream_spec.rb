require "rails_helper"

RSpec.describe DataStream, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:owner_organization).class_name("Organization") }
  end

  describe "validations" do
    subject { build(:data_stream) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:owner_organization) }
    it { is_expected.to validate_numericality_of(:retention_days).is_greater_than(0).allow_nil }

    describe "name presence" do
      it "is valid with a name" do
        data_stream = build(:data_stream, name: "CertDC")
        expect(data_stream).to be_valid
      end

      it "is invalid without a name" do
        data_stream = build(:data_stream, name: nil)
        expect(data_stream).not_to be_valid
        expect(data_stream.errors[:name]).to include("can't be blank")
      end
    end

    describe "retention_days validation" do
      it "accepts positive retention_days" do
        data_stream = build(:data_stream, retention_days: 365)
        expect(data_stream).to be_valid
      end

      it "accepts nil retention_days" do
        data_stream = build(:data_stream, retention_days: nil)
        expect(data_stream).to be_valid
      end

      it "rejects zero retention_days" do
        data_stream = build(:data_stream, retention_days: 0)
        expect(data_stream).not_to be_valid
        expect(data_stream.errors[:retention_days]).to include("must be greater than 0")
      end

      it "rejects negative retention_days" do
        data_stream = build(:data_stream, retention_days: -10)
        expect(data_stream).not_to be_valid
        expect(data_stream.errors[:retention_days]).to include("must be greater than 0")
      end
    end
  end

  describe "database constraints" do
    it "enforces foreign key constraint on owner_organization_id" do
      data_stream = build(:data_stream)
      data_stream.owner_organization_id = 999999

      expect {
        data_stream.save(validate: false)
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "generates unique UUIDs for multiple records" do
      stream1 = create(:data_stream)
      stream2 = create(:data_stream)
      stream3 = create(:data_stream)

      expect(stream1.uuid).not_to eq(stream2.uuid)
      expect(stream1.uuid).not_to eq(stream3.uuid)
      expect(stream2.uuid).not_to eq(stream3.uuid)
    end
  end

  describe "uuid generation" do
    it "automatically generates a UUID on creation" do
      data_stream = create(:data_stream)
      expect(data_stream.uuid).to be_present
      expect(data_stream.uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end
end
