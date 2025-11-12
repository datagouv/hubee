require "rails_helper"

RSpec.describe Organization, type: :model do
  it_behaves_like "a model with UUID v7 primary key"

  describe "associations" do
    it { is_expected.to have_many(:data_streams).with_foreign_key(:owner_organization_id).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:subscriptions).dependent(:destroy) }
    it { is_expected.to have_many(:transmitted_data_packages).class_name("DataPackage").with_foreign_key(:sender_organization_id).dependent(:restrict_with_error) }
  end

  describe "validations" do
    subject { build(:organization) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:siret) }
    it { is_expected.to validate_uniqueness_of(:siret).case_insensitive }
    it { is_expected.to allow_value("12345678901234").for(:siret) }
    it { is_expected.not_to allow_value("123", "123456789012345", "1234567890123A", "123 456 789 012").for(:siret).with_message("must be 14 digits") }
  end

  describe "database indexes" do
    it { is_expected.to have_db_index(:siret).unique }
  end
end
