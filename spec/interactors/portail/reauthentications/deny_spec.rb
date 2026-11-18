# frozen_string_literal: true

require "rails_helper"

# L'organizer de bout en bout : le motif retenu décide à la fois de la fermeture et de la trace.
RSpec.describe Portail::Reauthentications::Deny do
  let(:provider_session) { create(:provider_session) }

  it "closes the session and traces a mismatch when someone else came back" do
    result = described_class.call(error: :unknown_agent, provider_session:,
      claims: {sub: "sub-collegue", acr: "eidas1", amr: ["pwd"]}, email: "collegue@example.gouv.fr")

    expect(result).to have_attributes(reason: :reauthentication_mismatch, close_session: true)
    expect(AccessDecision.last).to have_attributes(outcome: "denied", kind: "reauthentication",
      reason: "reauthentication_mismatch", email: "collegue@example.gouv.fr",
      agent_id: provider_session.membership.agent_id)
  end

  it "keeps the session and traces an aborted reauthentication" do
    result = described_class.call(error: :reauthentication_aborted, provider_session:)

    expect(result).to have_attributes(reason: :reauthentication_aborted, close_session: false)
    expect(AccessDecision.last).to have_attributes(kind: "reauthentication", reason: "reauthentication_aborted")
  end

  it "keeps the session and traces nothing for an outage" do
    result = nil

    expect {
      result = described_class.call(error: :provider_unavailable, provider_session:)
    }.not_to change(AccessDecision, :count)

    expect(result).to have_attributes(reason: :provider_unavailable, close_session: false)
  end
end
