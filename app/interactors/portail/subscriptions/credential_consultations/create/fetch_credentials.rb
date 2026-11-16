# frozen_string_literal: true

module Portail
  module Subscriptions
    module CredentialConsultations
      class Create
        # Bornée sur l'organisation du rattachement, comme le détail : l'abonnement autorisé ne
        # fournit que son identifiant.
        class FetchCredentials
          include Interactor

          def call
            link = context.membership.organization_link
            context.credentials = HubAPI::Subscriptions.credentials(
              id: context.subscription.id, siret: link.siret, insee_code: link.insee_code
            )
          rescue HubAPI::NotFound, HubAPI::InvalidRequest
            # L'abonnement vient d'être lu : route absente d'un environnement, ou abonnement supprimé
            # entre-temps. Une anomalie pour l'exploitation, une indisponibilité pour l'agent.
            Rails.logger.warn("Identifiants d'abonnement introuvables en amont", subscription_id: context.subscription.id)
            context.fail!(error: :unavailable)
          rescue HubAPI::CredentialsRefused
            # Un cas pour l'équipe HubEE : l'identifiant suffit à retrouver l'abonnement.
            Rails.logger.info("Identifiants d'abonnement refusés en amont", subscription_id: context.subscription.id)
            context.fail!(error: :refused)
          rescue HubAPI::Error
            # La panne est déjà signalée par Portail::HubAPI.
            context.fail!(error: :unavailable)
          end
        end
      end
    end
  end
end
