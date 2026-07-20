# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::ProConnect::Discovery do
  let(:domain) { "https://proconnect.gouv.fr" }
  let(:openid_config) do
    {
      issuer: "https://proconnect.gouv.fr/api/v2",
      jwks_uri: "https://proconnect.gouv.fr/api/v2/jwks",
      end_session_endpoint: "https://proconnect.gouv.fr/api/v2/session/end"
    }
  end
  let(:jwks_document) { {keys: [{kty: "RSA", kid: "abc", n: "xxx", e: "AQAB"}]} }

  around do |example|
    ENV["PROCONNECT_DOMAIN"] = domain
    example.run
  ensure
    ENV.delete("PROCONNECT_DOMAIN")
    Rails.cache.clear
  end

  before do
    stub_request(:get, "#{domain}/.well-known/openid-configuration")
      .to_return(status: 200, body: openid_config.to_json, headers: {"Content-Type" => "application/json"})
    stub_request(:get, openid_config[:jwks_uri])
      .to_return(status: 200, body: jwks_document.to_json, headers: {"Content-Type" => "application/json"})
  end

  describe "#issuer" do
    it "returns the issuer from the discovery document" do
      expect(described_class.new.issuer).to eq("https://proconnect.gouv.fr/api/v2")
    end
  end

  describe "#end_session_endpoint" do
    it "returns the end_session_endpoint from the discovery document" do
      expect(described_class.new.end_session_endpoint).to eq("https://proconnect.gouv.fr/api/v2/session/end")
    end
  end

  describe "#jwks" do
    it "returns a JWK set built from the jwks_uri document" do
      jwks = described_class.new.jwks

      expect(jwks).to be_a(JSON::JWK::Set)
      expect(jwks.first[:kid]).to eq("abc")
    end
  end
end
