# frozen_string_literal: true

module Portail
  # Ne ramasse que les orphelines : une session expirée est détruite dès la requête
  # suivante de son propriétaire, et un refus disparaît avec la connexion qui le remplace.
  # Restent celles dont le navigateur n'est jamais revenu.
  class PurgeProviderSessionsJob < ApplicationJob
    # Un refus ne sert qu'à afficher une page qu'on quitte en quelques secondes, et sa
    # ligne porte un jeton et une adresse : on la garde le moins longtemps possible.
    DENIAL_RETENTION = 15.minutes

    def perform
      ProviderSession.denied.where(created_at: ..DENIAL_RETENTION.ago).delete_all
      ProviderSession.granted
        .where("updated_at < ? OR created_at < ?",
          SessionLifetime::IDLE.ago, SessionLifetime::ABSOLUTE.ago)
        .delete_all
    end
  end
end
