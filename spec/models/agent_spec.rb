# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agent, type: :model do
  describe "validations" do
    subject { build(:agent) }

    it { is_expected.to validate_uniqueness_of(:provider_sub).ignoring_case_sensitivity }

    # Un agent enrôlé existe avant d'avoir ouvert sa première session.
    it { is_expected.to allow_value(nil).for(:provider_sub) }
    it { is_expected.to validate_presence_of(:email) }

    # ignoring_case_sensitivity : le matcher éprouve la casse en la permutant, or
    # `normalizes` la rabat en minuscules — la permutation entre donc en collision.
    it { is_expected.to validate_uniqueness_of(:email).ignoring_case_sensitivity }
  end

  describe "civility" do
    # Facultative : l'absence est un état légitime — l'import ne doit pas échouer sur un
    # stock V1 incomplet, et personne n'est forcé de se déclarer.
    it "accepts the closed list and nothing else, absence included" do
      expect(build(:agent, civility: "mr")).to be_valid
      expect(build(:agent, civility: "ms")).to be_valid
      expect(build(:agent, civility: nil)).to be_valid
      expect(build(:agent, civility: "docteur")).not_to be_valid
    end
  end

  describe "labels" do
    it "names the attribute and each of its values in French" do
      expect(described_class.human_attribute_name(:civility)).to eq("Civilité")
      expect(described_class.human_attribute_name("civilities.mr")).to eq("M.")
      expect(described_class.human_attribute_name("civilities.ms")).to eq("Mme")
    end
  end

  describe "associations" do
    subject { build(:agent) }

    it { is_expected.to have_many(:memberships) }
    it { is_expected.to have_many(:organization_links).through(:memberships) }
  end
end
