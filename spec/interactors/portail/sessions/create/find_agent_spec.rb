# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Create::FindAgent do
  subject(:result) do
    described_class.call(
      claims: {sub: "sub-xyz", amr: ["pwd", "mfa"]},
      info: {email: "new@example.gouv.fr", first_name: "Alex", last_name: "Nouveau"}
    )
  end

  context "when an agent matches both the sub and the email" do
    it "returns the agent and refreshes names and authentication methods" do
      agent = create(:agent, provider_sub: "sub-xyz", email: "new@example.gouv.fr",
        first_name: "Alexandre", last_name: "Ancien", amr: ["pwd"])

      expect(result).to be_success
      expect(result.agent).to eq(agent)
      expect(agent.reload).to have_attributes(
        first_name: "Alex",
        last_name: "Nouveau",
        amr: ["pwd", "mfa"]
      )
    end
  end

  # Premier rapprochement d'un agent enrôlé, ou retour après un changement de fournisseur
  # d'identité — qui change le sub sans changer la personne.
  context "when no agent matches the sub but one holds the email" do
    it "binds the sub to that agent and lets them in" do
      agent = create(:agent, provider_sub: "sub-other", email: "new@example.gouv.fr")

      expect(result).to be_success
      expect(result.agent).to eq(agent)
      expect(agent.reload.provider_sub).to eq("sub-xyz")
    end
  end

  # Rare : un changement d'adresse s'accompagne le plus souvent d'un nouveau compte
  # ProConnect, donc d'un nouveau sub. Prévalence incertaine, on bloque par prudence.
  context "when the sub matches but the email does not" do
    it "refuses access without touching the record" do
      agent = create(:agent, provider_sub: "sub-xyz", email: "old@example.gouv.fr")

      expect(result).to be_failure
      expect(result.error).to eq(:email_mismatch)
      expect(agent.reload.email).to eq("old@example.gouv.fr")
    end
  end

  context "when neither the sub nor the email is known" do
    it "fails with unknown_agent and creates nothing" do
      expect { result }.not_to change(Agent, :count)

      expect(result).to be_failure
      expect(result.error).to eq(:unknown_agent)
    end
  end
end
