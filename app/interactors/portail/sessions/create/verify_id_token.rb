# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      class VerifyIdToken
        include Interactor
        include SemanticLogger::Loggable

        def call
          context.claims = Portail::ProConnect::TokenVerifier.call(
            id_token: context.id_token,
            nonce: context.nonce,
            audience: ENV.fetch("PROCONNECT_CLIENT_ID")
          )
        rescue Portail::ProConnect::TokenVerifier::InvalidToken
          # Aucun sujet, délibérément : tout ce que le jeton contient devient inutilisable au
          # moment où il échoue, et l'attribuer à un agent réel donnerait au support un faux
          # diagnostic. Seul le contexte de requête — IP, user_agent — qualifie ce refus.
          Rails.event.notify(Portail::Auth::Decision.new(outcome: :denied, reason: :invalid_token))
          context.fail!(error: :invalid_token)
        rescue Portail::ProConnect::Client::Unavailable => e
          # Vérifier la signature suppose d'aller chercher les clés publiques. ProConnect
          # muet, on ne peut ni accepter ni imputer quoi que ce soit à l'agent.
          logger.error("Découverte ProConnect indisponible", e)
          context.fail!(error: :provider_unavailable)
        end
      end
    end
  end
end
