# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Delivery::Recipient do
  describe "#matches?" do
    let(:organization_link) { build(:organization_link, siret: "22770001000019", insee_code: "77372") }

    it "matches the organisation with the same SIRET and INSEE code" do
      recipient = build(:portail_recipient, siret: "22770001000019", insee_code: "77372")

      expect(recipient.matches?(organization_link)).to be(true)
    end

    # Un SIRET seul ne désigne pas une organisation : plusieurs peuvent le porter, seul le code
    # INSEE les sépare.
    it "does not match another INSEE code under the same SIRET" do
      recipient = build(:portail_recipient, siret: "22770001000019", insee_code: "75056")

      expect(recipient.matches?(organization_link)).to be(false)
    end

    it "does not match another SIRET" do
      recipient = build(:portail_recipient, siret: "13002526500013", insee_code: "77372")

      expect(recipient.matches?(organization_link)).to be(false)
    end
  end
end
