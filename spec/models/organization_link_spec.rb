# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizationLink, type: :model do
  describe "validations" do
    subject { build(:organization_link) }

    it { is_expected.to validate_presence_of(:siret) }
    it { is_expected.to validate_presence_of(:insee_code) }

    # ignoring_case_sensitivity : le matcher éprouve la casse en la permutant, or un SIRET
    # n'a que des chiffres — il n'a rien à permuter et refuse de conclure.
    it { is_expected.to validate_uniqueness_of(:siret).scoped_to(:insee_code).ignoring_case_sensitivity }

    it { is_expected.to allow_value("13002526500013").for(:siret) }

    # Un SIRET espacé ou tronqué ne correspondrait jamais à celui attesté par ProConnect.
    it { is_expected.not_to allow_value("130 025 265 00013").for(:siret) }
    it { is_expected.not_to allow_value("1300252650001").for(:siret) }

    # Le critère d'acceptation de #688 : deux organisations partageant un SIRET sont deux liens.
    it "accepts two organizations sharing a SIRET under distinct branch codes" do
      create(:organization_link, siret: "99999999900001", insee_code: "001")

      twin = build(:organization_link, siret: "99999999900001", insee_code: "002")

      expect(twin).to be_valid
    end
  end

  describe "associations" do
    subject { build(:organization_link) }

    it { is_expected.to have_many(:memberships) }
    it { is_expected.to have_many(:agents).through(:memberships) }
  end
end
