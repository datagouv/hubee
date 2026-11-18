# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Reauthentications::Create do
  subject(:result) do
    described_class.call(code: "the-code", nonce: "nonce-1", provider_session:, purpose: "credentials:42",
      kind: :reauthentication, step_up_attempted: true)
  end

  let(:agent) { create(:agent, provider_sub: "sub-agent", email: "agent@example.gouv.fr") }
  let(:link) { create(:organization_link, siret: "99999999911111") }
  let(:membership) { create(:membership, agent:, organization_link: link, role: "local_administrator") }
  let(:provider_session) do
    create(:provider_session, membership:, provider_id_token: "old-token", provider_sid: "sid-sign-in", acr: "eidas1-mfa")
  end

  around do |example|
    original_client_id = ENV["PROCONNECT_CLIENT_ID"]
    ENV["PROCONNECT_CLIENT_ID"] = "client-abc"
    example.run
  ensure
    ENV["PROCONNECT_CLIENT_ID"] = original_client_id
  end

  def proconnect_returns(sub: "sub-agent", email: "agent@example.gouv.fr", siret: "99999999911111",
    acr: "eidas1-mfa", amr: ["mfa"], sid: "sid-reauthentication")
    expect(Portail::ProConnect::Client).to receive(:exchange).with(code: "the-code").and_return(
      Portail::ProConnect::Client::Tokens.new(id_token: "new-token",
        info: Portail::ProConnect::Client::Info.new(email:, first_name: "Alex", last_name: "Martin"),
        siret:, idp_id: "idp-1", organization_label: "Mairie de Test")
    )
    expect(Portail::ProConnect::TokenVerifier).to receive(:call).and_return(sub:, amr:, acr:, sid:)
  end

  before { freeze_time }

  it "records a proof for the purpose and adopts the new id_token" do
    proconnect_returns

    expect(result).to be_success
    expect(provider_session.reload).to have_attributes(reauthenticated_at: Time.current,
      reauthenticated_for: "credentials:42", provider_id_token: "new-token", acr: "eidas1-mfa", amr: ["mfa"])
  end

  # Le collègue qui empêche la déconnexion revient par la session ProConnect de l'agent, encore ouverte.
  it "fails without adopting anything when ProConnect reused the session of the sign-in" do
    proconnect_returns(sid: "sid-sign-in")

    expect(result.error).to eq(:reauthentication_without_logout)
    expect(provider_session.reload).to have_attributes(provider_id_token: "old-token", reauthenticated_at: nil)
  end

  # ProConnect attribue un `sub` par fournisseur d'identité : en changer est légitime.
  it "accepts the same agent under another sub" do
    proconnect_returns(sub: "sub-other-idp")

    expect(result).to be_success
  end

  it "fails as a mismatch for another agent of the same organisation" do
    create(:membership, agent: create(:agent, provider_sub: "sub-colleague", email: "collegue@example.gouv.fr"),
      organization_link: link)
    proconnect_returns(sub: "sub-colleague", email: "collegue@example.gouv.fr")

    expect(result).to be_failure
    expect(result.error).to eq(:reauthentication_mismatch)
    expect(provider_session.reload).to have_attributes(provider_id_token: "old-token", reauthenticated_at: nil)
  end

  it "fails for an agent unknown to the portal" do
    proconnect_returns(sub: "sub-stranger", email: "inconnu@example.gouv.fr")

    expect(result.error).to eq(:unknown_agent)
  end

  it "fails for the same agent under another organisation" do
    proconnect_returns(siret: "11111111100000")

    expect(result.error).to eq(:organization_mismatch)
    expect(provider_session.reload.reauthenticated_at).to be_nil
  end

  # La session ProConnect désormais ouverte est celle de l'agent : « Se déconnecter » doit la fermer.
  it "adopts the new id_token even when the second factor is missing" do
    proconnect_returns(acr: "eidas1", amr: ["pwd"])

    expect(result.error).to eq(:second_factor_required)
    expect(provider_session.reload).to have_attributes(provider_id_token: "new-token", acr: "eidas1-mfa",
      reauthenticated_at: nil)
  end

  it "emits a granted reauthentication decision" do
    proconnect_returns

    expect { result }.to change(AccessDecision, :count).by(1)
    expect(AccessDecision.last).to have_attributes(outcome: "granted", kind: "reauthentication",
      email: "agent@example.gouv.fr", provider_sub: "sub-agent", siret: "99999999911111", idp_id: "idp-1",
      acr: "eidas1-mfa", agent_id: agent.id, membership_id: membership.id)
  end
end
