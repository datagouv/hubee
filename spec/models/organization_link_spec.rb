# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizationLink, type: :model do
  describe "validations" do
    subject { build(:organization_link) }

    it { is_expected.to validate_presence_of(:siret) }

    # ignoring_case_sensitivity : le matcher éprouve la casse en la permutant, or un SIRET
    # n'a que des chiffres — il n'a rien à permuter et refuse de conclure.
    it { is_expected.to validate_uniqueness_of(:siret).ignoring_case_sensitivity }

    it { is_expected.to allow_value("13002526500013").for(:siret) }

    # Un SIRET espacé ou tronqué ne correspondrait jamais à celui attesté par ProConnect.
    it { is_expected.not_to allow_value("130 025 265 00013").for(:siret) }
    it { is_expected.not_to allow_value("1300252650001").for(:siret) }
  end

  describe "associations" do
    subject { build(:organization_link) }

    it { is_expected.to have_many(:memberships) }
    it { is_expected.to have_many(:agents).through(:memberships) }
  end
end
