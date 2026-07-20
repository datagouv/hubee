# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agent, type: :model do
  describe "validations" do
    subject { build(:agent) }

    it { is_expected.to validate_presence_of(:provider_sub) }
    it { is_expected.to validate_uniqueness_of(:provider_sub) }
    it { is_expected.to validate_presence_of(:email) }
  end
end
