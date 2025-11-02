require "rails_helper"

RSpec.describe Organization, type: :model do
  describe "validations" do
    subject { build(:organization) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:siret) }
    it { is_expected.to validate_uniqueness_of(:siret).case_insensitive }

    describe "siret format" do
      it "accepts valid 14-digit SIRET" do
        organization = build(:organization, siret: "12345678901234")
        expect(organization).to be_valid
      end

      it "rejects SIRET with less than 14 digits" do
        organization = build(:organization, siret: "123")
        expect(organization).not_to be_valid
        expect(organization.errors[:siret]).to include("must be 14 digits")
      end

      it "rejects SIRET with more than 14 digits" do
        organization = build(:organization, siret: "123456789012345")
        expect(organization).not_to be_valid
        expect(organization.errors[:siret]).to include("must be 14 digits")
      end

      it "rejects SIRET with non-numeric characters" do
        organization = build(:organization, siret: "1234567890123A")
        expect(organization).not_to be_valid
        expect(organization.errors[:siret]).to include("must be 14 digits")
      end

      it "rejects SIRET with spaces" do
        organization = build(:organization, siret: "123 456 789 012")
        expect(organization).not_to be_valid
        expect(organization.errors[:siret]).to include("must be 14 digits")
      end
    end
  end

  describe "database constraints" do
    it "enforces uniqueness of siret at database level" do
      create(:organization, siret: "12345678901234")
      duplicate = build(:organization, siret: "12345678901234")

      expect {
        duplicate.save(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "implicit_order_column" do
    let!(:organization1) { create(:organization, name: "First", siret: "11111111111111") }
    let!(:organization2) { create(:organization, name: "Second", siret: "22222222222222") }
    let!(:organization3) { create(:organization, name: "Third", siret: "33333333333333") }

    it "orders .first and .last by created_at instead of UUID" do
      expect(Organization.first).to eq(organization1)
      expect(Organization.last).to eq(organization3)
    end
  end
end
