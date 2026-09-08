# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscription do
  describe "#readable_via_portal?" do
    # Les deux conditions, éprouvées séparément : l'une sans l'autre ne suffit pas.
    it "is true for a reading subscription served through the portal only" do
      expect(build(:portail_subscription)).to be_readable_via_portal
      expect(build(:portail_subscription, read_package: false)).not_to be_readable_via_portal
      expect(build(:portail_subscription, access_mode: "api")).not_to be_readable_via_portal
    end
  end
end
