# frozen_string_literal: true

require "rails_helper"

# L'amont est un tiers : ce qu'il sert est vérifié contre l'organisation du rattachement, la
# requête l'ait déjà bornée ou non.
RSpec.describe Portail::Access::OrganizationPerimeter do
  let(:membership) do
    build(:membership, organization_link: build(:organization_link, siret: "22770001000019", insee_code: "77372"))
  end

  it "covers the recipient with the SIRET and INSEE code of the membership" do
    recipient = build(:portail_recipient, siret: "22770001000019", insee_code: "77372")

    expect(described_class.covers?(membership, recipient)).to be(true)
  end

  # Un SIRET seul ne désigne pas une organisation : plusieurs peuvent le porter, seul le code
  # INSEE les sépare.
  it "does not cover another INSEE code under the same SIRET" do
    recipient = build(:portail_recipient, siret: "22770001000019", insee_code: "75056")

    expect(described_class.covers?(membership, recipient)).to be(false)
  end

  it "does not cover another SIRET" do
    recipient = build(:portail_recipient, siret: "13002526500013", insee_code: "77372")

    expect(described_class.covers?(membership, recipient)).to be(false)
  end
end
