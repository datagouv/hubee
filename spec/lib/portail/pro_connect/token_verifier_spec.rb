# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::ProConnect::TokenVerifier do
  # Clé RSA de test + JWKS correspondant, injectés via un fake discovery.
  let(:rsa) { OpenSSL::PKey::RSA.generate(2048) }
  let(:jwk) { JSON::JWK.new(rsa.public_key) }
  let(:discovery) do
    instance_double(
      "Portail::ProConnect::Discovery",
      issuer: "https://proconnect.gouv.fr/api/v2",
      jwks: JSON::JWK::Set.new(jwk)
    )
  end

  # Construit un id_token signé. Les surcharges permettent de casser un claim.
  def signed_id_token(overrides = {})
    claims = {
      iss: "https://proconnect.gouv.fr/api/v2",
      aud: "client-abc",
      exp: 5.minutes.from_now.to_i,
      iat: Time.current.to_i,
      nonce: "nonce-123",
      sub: "sub-xyz",
      amr: ["pwd", "mfa"]
    }.merge(overrides)

    jwt = JSON::JWT.new(claims)
    jwt.kid = jwk[:kid]
    jwt.sign(rsa, :RS256).to_s
  end

  subject(:result) do
    described_class.call(
      id_token: id_token,
      nonce: "nonce-123",
      audience: "client-abc",
      discovery: discovery
    )
  end

  describe ".call" do
    context "with a valid, well-signed token" do
      let(:id_token) { signed_id_token }

      it "returns the sub and amr from the verified id_token" do
        expect(result).to eq(sub: "sub-xyz", amr: ["pwd", "mfa"])
      end
    end

    context "when the signature does not match the JWKS" do
      let(:id_token) do
        other_rsa = OpenSSL::PKey::RSA.generate(2048)
        jwt = JSON::JWT.new(iss: "https://proconnect.gouv.fr/api/v2", aud: "client-abc",
          exp: 5.minutes.from_now.to_i, nonce: "nonce-123", sub: "sub-xyz")
        jwt.kid = jwk[:kid]
        jwt.sign(other_rsa, :RS256).to_s
      end

      it "raises InvalidToken" do
        expect { result }.to raise_error(described_class::InvalidToken)
      end
    end

    context "when the nonce does not match" do
      let(:id_token) { signed_id_token(nonce: "tampered") }

      it "raises InvalidToken" do
        expect { result }.to raise_error(described_class::InvalidToken)
      end
    end

    context "when the issuer does not match" do
      let(:id_token) { signed_id_token(iss: "https://evil.example") }

      it "raises InvalidToken" do
        expect { result }.to raise_error(described_class::InvalidToken)
      end
    end

    context "when the audience does not match" do
      let(:id_token) { signed_id_token(aud: "another-client") }

      it "raises InvalidToken" do
        expect { result }.to raise_error(described_class::InvalidToken)
      end
    end

    context "when the token is expired" do
      let(:id_token) { signed_id_token(exp: 1.minute.ago.to_i) }

      it "raises InvalidToken" do
        expect { result }.to raise_error(described_class::InvalidToken)
      end
    end

    context "when the token is signed with a non-allowed algorithm" do
      let(:id_token) do
        claims = {
          iss: "https://proconnect.gouv.fr/api/v2",
          aud: "client-abc",
          exp: 5.minutes.from_now.to_i,
          iat: Time.current.to_i,
          nonce: "nonce-123",
          sub: "sub-xyz",
          amr: ["pwd", "mfa"]
        }
        jwt = JSON::JWT.new(claims)
        jwt.kid = jwk[:kid]
        jwt.sign(rsa.to_s, :HS256).to_s
      end

      it "raises InvalidToken" do
        expect { result }.to raise_error(described_class::InvalidToken)
      end
    end

    context "when the expected nonce is nil" do
      subject(:result) do
        described_class.call(
          id_token: id_token,
          nonce: nil,
          audience: "client-abc",
          discovery: discovery
        )
      end

      let(:id_token) { signed_id_token }

      it "raises InvalidToken" do
        expect { result }.to raise_error(described_class::InvalidToken)
      end
    end
  end
end
