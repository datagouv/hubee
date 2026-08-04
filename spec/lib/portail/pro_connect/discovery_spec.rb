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
  let(:rotated_jwks_document) { {keys: [{kty: "RSA", kid: "def", n: "yyy", e: "AQAB"}]} }

  # L'environnement de test utilise :null_store, qui n'enregistre rien : les exemples sur
  # le cache et sur le verrou passeraient au vert sans rien exercer. On pose donc un vrai
  # magasin, neuf à chaque exemple.
  around do |example|
    original_domain = ENV["PROCONNECT_DOMAIN"]
    original_cache = Rails.cache
    ENV["PROCONNECT_DOMAIN"] = domain
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    ENV["PROCONNECT_DOMAIN"] = original_domain
    Rails.cache = original_cache
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

  # Une panne de ProConnect doit se présenter aux appelants sous une seule forme, pour
  # qu'ils puissent dégrader au lieu de laisser fuir une exception de transport.
  describe "when ProConnect cannot be reached or understood" do
    it "raises Unavailable on a non-success response" do
      stub_request(:get, "#{domain}/.well-known/openid-configuration")
        .to_return(status: 502, body: "<html>Bad Gateway</html>")

      expect { described_class.new.issuer }
        .to raise_error(described_class::Unavailable, /502/)
    end

    it "raises Unavailable when the connection fails" do
      stub_request(:get, "#{domain}/.well-known/openid-configuration").to_timeout

      expect { described_class.new.issuer }.to raise_error(described_class::Unavailable)
    end

    it "raises Unavailable when the body is not the expected JSON" do
      stub_request(:get, "#{domain}/.well-known/openid-configuration")
        .to_return(status: 200, body: "pas du json")

      expect { described_class.new.issuer }.to raise_error(described_class::Unavailable)
    end

    # Un annuaire bien formé mais amputé est tout aussi inexploitable.
    it "raises Unavailable when the expected key is missing" do
      stub_request(:get, "#{domain}/.well-known/openid-configuration")
        .to_return(status: 200, body: {jwks_uri: "https://x.test/jwks"}.to_json)

      expect { described_class.new.issuer }
        .to raise_error(described_class::Unavailable, /issuer/)
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

    context "when the requested kid is absent from the cached set" do
      it "reloads the JWKS, so a rotated key is picked up without waiting for the TTL" do
        # Deux réponses successives : l'ancienne clé, puis la nouvelle — la rotation vue
        # depuis notre côté.
        stub_request(:get, openid_config[:jwks_uri]).to_return(
          {status: 200, body: jwks_document.to_json, headers: {"Content-Type" => "application/json"}},
          {status: 200, body: rotated_jwks_document.to_json, headers: {"Content-Type" => "application/json"}}
        )

        jwks = described_class.new.jwks(kid: "def")

        expect(jwks.first[:kid]).to eq("def")
      end
    end

    context "when unknown kids keep arriving" do
      it "reloads at most once per cooldown, so forged kids cannot hammer ProConnect" do
        described_class.new.jwks(kid: "forged-1")
        described_class.new.jwks(kid: "forged-2")

        expect(a_request(:get, openid_config[:jwks_uri])).to have_been_made.twice
      end
    end
  end

  describe "transport security" do
    let(:domain) { "http://proconnect.gouv.fr" }

    it "refuses to fetch ProConnect metadata over plaintext" do
      expect { described_class.new.issuer }.to raise_error(ArgumentError, /non HTTPS/)
    end
  end
end
