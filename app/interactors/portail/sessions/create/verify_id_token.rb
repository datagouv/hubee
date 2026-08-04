# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      class VerifyIdToken
        include Interactor

        def call
          context.claims = Portail::ProConnect::TokenVerifier.call(
            id_token: context.id_token,
            nonce: context.nonce,
            audience: ENV.fetch("PROCONNECT_CLIENT_ID")
          )
        rescue Portail::ProConnect::TokenVerifier::InvalidToken => e
          Rails.logger.warn("[ProConnect] id_token rejected: #{e.message}")
          context.fail!(error: :invalid_token)
        rescue Portail::ProConnect::Discovery::Unavailable => e
          # Vérifier la signature suppose d'aller chercher les clés publiques. ProConnect
          # muet, on ne peut ni accepter ni imputer quoi que ce soit à l'agent.
          Rails.logger.error("[ProConnect] discovery unavailable: #{e.message}")
          context.fail!(error: :provider_unavailable)
        end
      end
    end
  end
end
