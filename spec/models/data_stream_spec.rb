require "rails_helper"

RSpec.describe DataStream, type: :model do
  it_behaves_like "a model with UUID v7 primary key"

  describe "associations" do
    it { is_expected.to belong_to(:owner_organization).class_name("Organization") }
    it { is_expected.to have_many(:subscriptions).dependent(:destroy) }
    it { is_expected.to have_many(:data_packages).dependent(:restrict_with_error) }
  end

  describe "validations" do
    subject { build(:data_stream) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:retention_days).is_greater_than(0).allow_nil }
  end

  describe "database indexes" do
    it { is_expected.to have_db_index(:owner_organization_id) }
  end
end
