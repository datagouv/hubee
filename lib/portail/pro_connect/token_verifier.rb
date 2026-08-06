# frozen_string_literal: true

require "json/jwt"

module Portail
  module ProConnect
    # Seul endroit où l'id_token est contrôlé. Le gem porte la signature et le jeu de
    # clés ; les contrôles de contenu restent ici — `IdToken#verify!` n'en fait que
    # quatre, sans marge d'horloge et en acceptant un nonce attendu nul.
    class TokenVerifier
      class InvalidToken < StandardError; end

      # Imposé, jamais lu dans le jeton : un HS256 signé avec la clé publique passerait sinon.
      ALLOWED_ALGORITHMS = [:RS256].freeze

      # Dérive entre horloges : sans marge, des jetons valides seraient refusés par à-coups.
      CLOCK_LEEWAY = 30.seconds

      class << self
        def call(id_token:, nonce:, audience:, config: Client.config)
          new(id_token:, nonce:, audience:, config:).call
        end
      end

      def initialize(id_token:, nonce:, audience:, config:)
        @id_token = id_token
        @nonce = nonce
        @audience = audience
        @config = config
      end

      def call
        claims = decode_and_verify_signature
        verify_claims!(claims)
        {sub: claims[:sub], amr: Array(claims[:amr]), acr: claims[:acr]}
      end

      private

      attr_reader :id_token, :nonce, :audience, :config

      # `config.jwk` va chercher chez ProConnect toute clé absente du cache (rotation).
      def decode_and_verify_signature
        JSON::JWT.decode(id_token, config.jwk(token_kid), ALLOWED_ALGORITHMS)
      rescue JSON::JWT::Exception, JSON::JWK::Set::KidNotFound => e
        raise InvalidToken, "signature verification failed: #{e.message}"
      end

      # Lu sans vérifier : ne sert qu'à choisir la clé, la signature est contrôlée juste après.
      def token_kid
        JSON::JWT.decode(id_token, :skip_verification).header[:kid]
      rescue JSON::JWT::Exception
        nil
      end

      # La signature prouve l'émetteur ; le contenu reste à contrôler. Un `sub` absent
      # ferait joker dans la résolution d'agent ; le `nonce` lie le jeton à notre demande
      # et interdit le rejeu.
      def verify_claims!(claims)
        raise InvalidToken, "missing subject" if claims[:sub].blank?
        raise InvalidToken, "issuer mismatch" unless claims[:iss] == config.issuer
        raise InvalidToken, "audience mismatch" unless Array(claims[:aud]).include?(audience)
        raise InvalidToken, "token expired" if claims[:exp].to_i <= (Time.current - CLOCK_LEEWAY).to_i
        raise InvalidToken, "nonce mismatch" unless nonce.present? && claims[:nonce] == nonce
      end
    end
  end
end
