# frozen_string_literal: true

require "json/jwt"

module Portail
  module ProConnect
    # Vérifie un id_token ProConnect (la gem omniauth-proconnect 0.6 ne le fait pas) :
    # signature contre le JWKS, nonce, iss/aud/exp. Retourne l'identité de confiance.
    class TokenVerifier
      class InvalidToken < StandardError; end

      def self.call(id_token:, nonce:, audience:, discovery: Discovery.new)
        new(id_token:, nonce:, audience:, discovery:).call
      end

      def initialize(id_token:, nonce:, audience:, discovery:)
        @id_token = id_token
        @nonce = nonce
        @audience = audience
        @discovery = discovery
      end

      def call
        claims = decode_and_verify_signature
        verify_claims!(claims)
        {sub: claims[:sub], amr: Array(claims[:amr])}
      end

      private

      attr_reader :id_token, :nonce, :audience, :discovery

      def decode_and_verify_signature
        JSON::JWT.decode(id_token, discovery.jwks)
      rescue JSON::JWT::Exception => e
        raise InvalidToken, "signature verification failed: #{e.message}"
      end

      def verify_claims!(claims)
        raise InvalidToken, "issuer mismatch" unless claims[:iss] == discovery.issuer
        raise InvalidToken, "audience mismatch" unless Array(claims[:aud]).include?(audience)
        raise InvalidToken, "token expired" if claims[:exp].to_i <= Time.now.to_i
        raise InvalidToken, "nonce mismatch" unless claims[:nonce] == nonce
      end
    end
  end
end
