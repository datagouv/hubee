# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Create do
  subject(:result) do
    described_class.call(
      id_token: "raw-token",
      nonce: "nonce-1",
      info: Portail::ProConnect::Client::Info.new(
        email: "agent@example.gouv.fr", first_name: "Alex", last_name: "Martin"
      ),
      siret: "99999999911111"
    )
  end

  around do |example|
    original_client_id = ENV["PROCONNECT_CLIENT_ID"]
    ENV["PROCONNECT_CLIENT_ID"] = "client-abc"
    example.run
  ensure
    ENV["PROCONNECT_CLIENT_ID"] = original_client_id
  end

  context "when the token is valid and the agent is attached to the certified organisation" do
    it "runs the whole chain and resolves both the agent and the membership" do
      agent = create(:agent, provider_sub: nil, email: "agent@example.gouv.fr",
        first_name: "Ancien")
      link = create(:organization_link, siret: "99999999911111")
      membership = create(:membership, agent: agent, organization_link: link)
      expect(Portail::ProConnect::TokenVerifier).to receive(:call)
        .and_return(sub: "sub-xyz", amr: ["mfa"], acr: "eidas1")

      expect(result).to be_success
      expect(result.agent).to eq(agent)
      expect(result.membership).to eq(membership)
      expect(agent.reload).to have_attributes(provider_sub: "sub-xyz", first_name: "Alex")
      expect(result.provider_session).to have_attributes(membership: membership,
        provider_id_token: "raw-token", acr: "eidas1")
    end
  end

  # Le refus tombe après la résolution de l'agent : la chaîne ne doit rien avoir écrit.
  context "when the agent is attached to another organisation" do
    it "fails without touching the agent record" do
      agent = create(:agent, provider_sub: nil, email: "agent@example.gouv.fr",
        first_name: "Inchangé")
      create(:membership, agent: agent,
        organization_link: create(:organization_link, siret: "11111111122222"))
      expect(Portail::ProConnect::TokenVerifier).to receive(:call)
        .and_return(sub: "sub-xyz", amr: ["mfa"], acr: "eidas1")

      expect(result).to be_failure
      expect(result.error).to eq(:organization_mismatch)
      expect(agent.reload).to have_attributes(provider_sub: nil, first_name: "Inchangé")
    end
  end
end
