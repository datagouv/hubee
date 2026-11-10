# frozen_string_literal: true

module Portail
  module Subscriptions
    module Credentials
      class Create
        class FetchCredentials
          include Interactor

          def call
            link = context.membership.organization_link
            context.credentials = HubAPI::Subscriptions.credentials(
              id: context.subscription.id, siret: link.siret, insee_code: link.insee_code
            )
          rescue HubAPI::NotFound, HubAPI::InvalidRequest
            # L'abonnement vient d'être lu : l'amont ne le reconnaît plus, ou plus dans ce périmètre.
            Rails.logger.info("Identifiants d'un abonnement introuvables en amont", id: context.subscription.id)
            context.fail!(error: :not_found)
          rescue HubAPI::CredentialsRefused => e
            # Un refus métier, pas un incident : la raison suffit au journal comme à l'écran.
            Rails.logger.info("Identifiants d'un abonnement refusés par l'amont",
              id: context.subscription.id, reason: e.reason)
            context.fail!(error: :refused, reason: e.reason)
          rescue HubAPI::Error => e
            # L'incident est déjà signalé par Portail::HubAPI, qui a traduit la panne.
            Rails.logger.error("Identifiants d'un abonnement indisponibles — #{e.class} : #{e.message}")
            context.fail!(error: :unavailable)
          end
        end
      end
    end
  end
end
