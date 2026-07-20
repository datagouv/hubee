# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Create do
  subject(:result) do
    described_class.call(
      id_token: "raw-token",
      nonce: "nonce-1",
      info: {email: "agent@example.gouv.fr", first_name: "Alex", last_name: "Martin"}
    )
  end

  around do |example|
    original_client_id = ENV["PROCONNECT_CLIENT_ID"]
    ENV["PROCONNECT_CLIENT_ID"] = "client-abc"
    example.run
  ensure
    ENV["PROCONNECT_CLIENT_ID"] = original_client_id
  end

  context "when the token is valid and the agent is known" do
    it "verifies the token then resolves the agent by sub" do
      create(:agent, provider_sub: "sub-xyz")
      expect(Portail::ProConnect::TokenVerifier).to receive(:call)
        .and_return(sub: "sub-xyz", amr: ["mfa"])

      expect(result).to be_success
      expect(result.agent.provider_sub).to eq("sub-xyz")
    end
  end
end
