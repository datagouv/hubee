# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Deny::RecordRefusal do
  describe ".call" do
    it "records a denied session carrying what the refusal page needs" do
      result = described_class.call(
        reason: :organization_mismatch, id_token: "raw-token",
        email: "agent@example.gouv.fr", organization_label: "Mairie de Test",
        claims: {amr: ["pwd"], acr: "eidas1"}
      )

      expect(result).to be_success
      expect(result.provider_session).to have_attributes(
        membership: nil, denial_reason: "organization_mismatch",
        email: "agent@example.gouv.fr", organization_label: "Mairie de Test",
        provider_id_token: "raw-token", amr: ["pwd"], acr: "eidas1"
      )
      expect(result.provider_session).to be_denied
    end

    it "fails with incomplete_identity and records nothing when ProConnect sent no address" do
      result = nil

      expect {
        result = described_class.call(
          reason: :organization_mismatch, id_token: "raw-token",
          email: nil, organization_label: "Mairie de Test",
          claims: {amr: ["pwd"], acr: "eidas1"}
        )
      }.not_to change(ProviderSession, :count)

      expect(result).to be_failure
      expect(result.error).to eq(:incomplete_identity)
    end
  end
end
