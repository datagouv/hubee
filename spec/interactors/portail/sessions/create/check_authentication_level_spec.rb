# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Create::CheckAuthenticationLevel do
  subject(:result) { described_class.call(claims: {acr: acr}) }

  context "when the level certifies the organisational link" do
    let(:acr) { "eidas1" }

    it "succeeds" do
      expect(result).to be_success
    end
  end

  context "when the organisational link is only declarative" do
    let(:acr) { "eidas0" }

    it "fails with insufficient_authentication_level" do
      expect(result).to be_failure
      expect(result.error).to eq(:insufficient_authentication_level)
    end
  end

  # Le second facteur ne dit rien du lien organisationnel : au niveau 0 il reste déclaratif.
  context "when a second factor was used but the level stays declarative" do
    let(:acr) { "eidas0-mfa" }

    it "fails with insufficient_authentication_level" do
      expect(result).to be_failure
      expect(result.error).to eq(:insufficient_authentication_level)
    end
  end

  context "when the level is absent" do
    let(:acr) { nil }

    it "fails with insufficient_authentication_level" do
      expect(result).to be_failure
      expect(result.error).to eq(:insufficient_authentication_level)
    end
  end
end
