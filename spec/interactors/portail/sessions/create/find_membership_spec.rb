# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Create::FindMembership do
  subject(:result) { described_class.call(agent: agent, siret: "99999999911111") }

  let(:agent) { create(:agent) }

  context "when the agent is attached to the organisation ProConnect certifies" do
    it "returns the membership" do
      link = create(:organization_link, siret: "99999999911111")
      membership = create(:membership, agent: agent, organization_link: link)

      expect(result).to be_success
      expect(result.membership).to eq(membership)
    end
  end

  context "when the agent has no membership at all" do
    it "fails with organization_mismatch" do
      expect(result).to be_failure
      expect(result.error).to eq(:organization_mismatch)
    end
  end

  context "when the agent is attached to another organisation" do
    it "fails with organization_mismatch" do
      link = create(:organization_link, siret: "99999999922222")
      create(:membership, agent: agent, organization_link: link)

      expect(result).to be_failure
      expect(result.error).to eq(:organization_mismatch)
    end
  end

  context "when two organizations share the SIRET ProConnect certifies" do
    # L'organisation homonyme est habitée par un autre agent : une recherche qui
    # perdrait son scope par agent pourrait retourner ce voisin.
    it "returns the membership of the agent's own organization" do
      twin_link = create(:organization_link, siret: "99999999911111", insee_code: "001")
      create(:membership, agent: create(:agent), organization_link: twin_link)
      own_link = create(:organization_link, siret: "99999999911111", insee_code: "002")
      membership = create(:membership, agent: agent, organization_link: own_link)

      expect(result).to be_success
      expect(result.membership).to eq(membership)
    end
  end
end
