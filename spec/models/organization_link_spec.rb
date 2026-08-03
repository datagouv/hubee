# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizationLink, type: :model do
  describe "validations" do
    subject { build(:organization_link) }

    it { is_expected.to validate_presence_of(:siret) }

    # ignoring_case_sensitivity : le matcher éprouve la casse en la permutant, or un SIRET
    # n'a que des chiffres — il n'a rien à permuter et refuse de conclure.
    it { is_expected.to validate_uniqueness_of(:siret).ignoring_case_sensitivity }
  end

  describe "associations" do
    subject { build(:organization_link) }

    it { is_expected.to have_many(:memberships) }
    it { is_expected.to have_many(:agents).through(:memberships) }
  end
end
