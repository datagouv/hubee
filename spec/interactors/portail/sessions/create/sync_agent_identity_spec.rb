# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Create::SyncAgentIdentity do
  describe ".call" do
    it "binds the ProConnect account and refreshes the identity it attests" do
      agent = create(:agent, provider_sub: nil, first_name: "Alexandre", last_name: "Ancien")

      result = described_class.call(
        agent: agent,
        claims: {sub: "sub-xyz"},
        info: Portail::ProConnect::Client::Info.new(
          email: nil, first_name: "Alex", last_name: "Nouveau"
        )
      )

      expect(result).to be_success
      expect(agent.reload).to have_attributes(
        provider_sub: "sub-xyz",
        first_name: "Alex",
        last_name: "Nouveau"
      )
    end

    # Deux connexions simultanées d'un agent jamais rattaché : la seconde bute sur
    # l'index unique. Sans ce rescue, l'exception traverserait jusqu'au 500.
    it "fails with sign_in_conflict when the sub was bound concurrently" do
      agent = create(:agent, provider_sub: nil)
      create(:agent, provider_sub: "sub-xyz")

      result = described_class.call(agent: agent, claims: {sub: "sub-xyz"},
        info: Portail::ProConnect::Client::Info.new(email: nil, first_name: nil, last_name: nil))

      expect(result).to be_failure
      expect(result.error).to eq(:sign_in_conflict)
    end
  end
end
