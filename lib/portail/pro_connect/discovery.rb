# frozen_string_literal: true

require "net/http"
require "json"
require "json/jwt"

module Portail
  module ProConnect
    # Récupère et met en cache la configuration OpenID Connect de ProConnect
    # (.well-known) et son JWKS. TTL 1 h : couvre la rotation des clés.
    class Discovery
      DISCOVERY_PATH = "/.well-known/openid-configuration"
      CACHE_TTL = 1.hour

      def issuer
        config.fetch("issuer")
      end

      def end_session_endpoint
        config.fetch("end_session_endpoint")
      end

      def jwks
        raw = Rails.cache.fetch("proconnect:jwks", expires_in: CACHE_TTL) do
          fetch_json(config.fetch("jwks_uri"))
        end
        JSON::JWK::Set.new(raw)
      end

      private

      def config
        @config ||= Rails.cache.fetch("proconnect:discovery", expires_in: CACHE_TTL) do
          fetch_json("#{ENV.fetch("PROCONNECT_DOMAIN")}#{DISCOVERY_PATH}")
        end
      end

      def fetch_json(url)
        JSON.parse(Net::HTTP.get(URI(url)))
      end
    end
  end
end
