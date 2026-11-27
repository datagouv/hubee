# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Create::OpenSession do
  describe ".call" do
    it "opens a session carrying the token and what ProConnect asserted" do
      membership = create(:membership)

      result = described_class.call(
        membership: membership, agent: membership.agent, id_token: "raw-token",
        claims: {amr: ["mfa"], acr: "eidas1", sid: "sid-1"},
        # Posé par SyncAgentIdentity, qui tourne juste avant dans l'organizer.
        provider_sub_changed: false
      )

      expect(result).to be_success
      expect(result.provider_session).to have_attributes(
        membership: membership, provider_id_token: "raw-token",
        email: membership.agent.email, amr: ["mfa"], acr: "eidas1", provider_sid: "sid-1"
      )
      expect(result.provider_session).to be_granted
    end

    # Sans `sid`, aucune réauthentification ne pourra être prouvée sur cette session : la connexion
    # n'est pas refusée pour autant, mais le journal le signale, pour qu'une omission de ProConnect se
    # voie avant que les agents ne tournent en rond.
    it "warns when ProConnect opens the session without a sid" do
      membership = create(:membership)

      events = capture_semantic_logger_events do
        described_class.call(membership:, agent: membership.agent, id_token: "raw-token",
          claims: {amr: ["mfa"], acr: "eidas1", sid: nil}, provider_sub_changed: false)
      end

      expect(events).to include(be_a_semantic_logger_event(level: :warn,
        message: "Session ProConnect sans sid : aucune réauthentification ne pourra y être prouvée",
        payload_includes: {membership_id: membership.id}))
    end

    it "records when the agent last signed in to this organisation" do
      freeze_time
      membership = create(:membership)

      described_class.call(
        membership: membership, agent: membership.agent, id_token: "raw-token",
        claims: {amr: ["mfa"], acr: "eidas1"}, provider_sub_changed: false
      )

      expect(membership.reload.last_signed_in_at).to eq(Time.current)
    end
  end
end
