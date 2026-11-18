# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Reauthentications::Create::RecordProof do
  it "records the proof for the purpose" do
    freeze_time
    provider_session = create(:provider_session)

    described_class.call(provider_session:, purpose: "credentials:42", id_token: "new-token",
      claims: {sub: "sub-agent", acr: "eidas1-mfa", amr: ["mfa"]}, agent: provider_session.membership.agent,
      membership: provider_session.membership, siret: "99999999911111")

    expect(provider_session.reload).to have_attributes(reauthenticated_at: Time.current,
      reauthenticated_for: "credentials:42", reauthentication_consumed_at: nil)
    expect(AccessDecision.last).to have_attributes(outcome: "granted", kind: "reauthentication")
  end
end
