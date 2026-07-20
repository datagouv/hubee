# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Create::FindAgent do
  subject(:result) do
    described_class.call(
      claims: {sub: "sub-xyz", amr: ["pwd", "mfa"]},
      info: {email: "new@example.gouv.fr", first_name: "Alex", last_name: "Nouveau"}
    )
  end

  context "when an agent exists for the sub" do
    it "returns the agent and refreshes email, names and amr" do
      agent = create(:agent, provider_sub: "sub-xyz", email: "old@example.gouv.fr", amr: ["pwd"])

      expect(result).to be_success
      expect(result.agent).to eq(agent)
      expect(agent.reload).to have_attributes(
        email: "new@example.gouv.fr",
        first_name: "Alex",
        last_name: "Nouveau",
        amr: ["pwd", "mfa"]
      )
    end
  end

  context "when no agent exists for the sub" do
    it "fails with unknown_agent and creates nothing" do
      expect { result }.not_to change(Agent, :count)

      expect(result).to be_failure
      expect(result.error).to eq(:unknown_agent)
    end
  end
end
