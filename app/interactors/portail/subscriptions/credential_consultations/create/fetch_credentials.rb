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
            # Supprimé entre la lecture du détail et le clic : introuvable, comme sur le détail.
            Rails.logger.info("Identifiants d'abonnement introuvables en amont", subscription_id: context.subscription.id)
            context.fail!(error: :not_found)
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
