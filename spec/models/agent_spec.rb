# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agent, type: :model do
  describe "validations" do
    subject { build(:agent) }

    it { is_expected.to validate_uniqueness_of(:provider_sub).ignoring_case_sensitivity }

    # Un agent enrôlé existe avant d'avoir ouvert sa première session.
    it { is_expected.to allow_value(nil).for(:provider_sub) }
    it { is_expected.to validate_presence_of(:email) }
  end

  describe "associations" do
    subject { build(:agent) }

    it { is_expected.to have_many(:memberships) }
    it { is_expected.to have_many(:organization_links).through(:memberships) }
  end
end
