# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Create::VerifyIdToken do
  subject(:result) { described_class.call(id_token: "raw-token", nonce: "nonce-1") }

  around do |example|
    original_client_id = ENV["PROCONNECT_CLIENT_ID"]
    ENV["PROCONNECT_CLIENT_ID"] = "client-abc"
    example.run
  ensure
    ENV["PROCONNECT_CLIENT_ID"] = original_client_id
  end

  context "when the token verifier accepts the token" do
    it "stores the verified claims on the context" do
      expect(Portail::ProConnect::TokenVerifier).to receive(:call)
        .with(id_token: "raw-token", nonce: "nonce-1", audience: "client-abc")
        .and_return(sub: "sub-xyz", amr: ["pwd", "mfa"])

      expect(result).to be_success
      expect(result.claims).to eq(sub: "sub-xyz", amr: ["pwd", "mfa"])
    end
  end

  context "when the token verifier rejects the token" do
    it "fails with invalid_token" do
      expect(Portail::ProConnect::TokenVerifier).to receive(:call)
        .and_raise(Portail::ProConnect::TokenVerifier::InvalidToken)

      expect(result).to be_failure
      expect(result.error).to eq(:invalid_token)
    end
  end

  # Vérifier la signature suppose d'aller chercher les clés publiques : ProConnect muet,
  # on ne peut rien imputer à l'agent — c'est une panne, pas un refus.
  context "when ProConnect cannot be reached" do
    it "fails with provider_unavailable" do
      expect(Portail::ProConnect::TokenVerifier).to receive(:call)
        .and_raise(Portail::ProConnect::Client::Unavailable)

      expect(result).to be_failure
      expect(result.error).to eq(:provider_unavailable)
    end
  end
end
