# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Create::OpenSession do
  describe ".call" do
    it "opens a session carrying the token and what ProConnect asserted" do
      membership = create(:membership)

      result = described_class.call(
        membership: membership, agent: membership.agent, id_token: "raw-token",
        claims: {amr: ["mfa"], acr: "eidas1"},
        # Posé par SyncAgentIdentity, qui tourne juste avant dans l'organizer.
        provider_sub_changed: false
      )

      expect(result).to be_success
      expect(result.provider_session).to have_attributes(
        membership: membership, provider_id_token: "raw-token",
        email: membership.agent.email, amr: ["mfa"], acr: "eidas1"
      )
      expect(result.provider_session).to be_granted
    end
  end
end
