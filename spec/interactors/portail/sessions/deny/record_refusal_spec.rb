# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Deny::RecordRefusal do
  describe ".call" do
    subject(:result) do
      described_class.call(
        reason: :organization_mismatch, id_token: "raw-token",
        email: email, organization_label: "Mairie de Test",
        claims: {amr: ["pwd"], acr: "eidas1"}
      )
    end

    context "when ProConnect returned an email" do
      let(:email) { "agent@example.gouv.fr" }

      it "records a denied session carrying what the refusal page needs" do
        expect(result).to be_success
        expect(result.provider_session).to have_attributes(
          membership: nil, denial_reason: "organization_mismatch",
          email: "agent@example.gouv.fr", organization_label: "Mairie de Test",
          provider_id_token: "raw-token", amr: ["pwd"], acr: "eidas1"
        )
        expect(result.provider_session).to be_denied
      end
    end

    context "when ProConnect returned no email" do
      let(:email) { nil }

      it "fails with incomplete_identity and records nothing" do
        expect { expect(result).to be_failure }.not_to change(ProviderSession, :count)
        expect(result.error).to eq(:incomplete_identity)
      end
    end
  end
end
