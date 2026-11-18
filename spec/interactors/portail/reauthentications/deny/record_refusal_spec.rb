# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Reauthentications::Deny::RecordRefusal do
  let(:provider_session) { create(:provider_session) }

  # Ce que ProConnect a présenté, et la session dont l'agent demandait la réauthentification : c'est
  # elle que le support et le CSIRT retrouvent.
  it "traces what ProConnect presented against the session's agent" do
    described_class.call(reason: :reauthentication_mismatch, traced: true, provider_session:,
      claims: {sub: "sub-collegue", acr: "eidas1-mfa", amr: ["mfa"]}, email: "collegue@example.gouv.fr",
      siret: "99999999911111", idp_id: "idp-1", organization_label: "Mairie de Test")

    expect(AccessDecision.last).to have_attributes(outcome: "denied", kind: "reauthentication",
      reason: "reauthentication_mismatch", email: "collegue@example.gouv.fr", provider_sub: "sub-collegue",
      siret: "99999999911111", idp_id: "idp-1", organization_label: "Mairie de Test", acr: "eidas1-mfa",
      amr: ["mfa"], agent_id: provider_session.membership.agent_id, membership_id: provider_session.membership_id)
  end

  # Un retour en erreur de ProConnect ne présente personne.
  it "traces a refusal with nothing presented" do
    described_class.call(reason: :reauthentication_aborted, traced: true, provider_session:, claims: {})

    expect(AccessDecision.last).to have_attributes(reason: "reauthentication_aborted", email: nil, amr: [],
      agent_id: provider_session.membership.agent_id)
  end

  it "traces nothing for a refusal already traced or imputable to no one" do
    expect {
      described_class.call(reason: :invalid_token, traced: false, provider_session:, claims: {})
    }.not_to change(AccessDecision, :count)
  end
end
