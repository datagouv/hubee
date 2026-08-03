# frozen_string_literal: true

require "rails_helper"

RSpec.describe Membership, type: :model do
  describe "associations" do
    subject { build(:membership) }

    it { is_expected.to belong_to(:agent) }
    it { is_expected.to belong_to(:organization_link) }
  end

  describe "validations" do
    subject { build(:membership) }

    # ignoring_case_sensitivity : le matcher fabrique « une autre valeur » en permutant la
    # casse de l'UUID, que PostgreSQL renormalise — il conclurait à tort que la validation
    # est trop stricte.
    it {
      is_expected.to validate_uniqueness_of(:agent_id)
        .scoped_to(:organization_link_id)
        .ignoring_case_sensitivity
    }
  end
end
