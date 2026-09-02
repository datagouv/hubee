# frozen_string_literal: true

module Portail
  module Deliveries
    class Show
      class FindDelivery
        include Interactor

        def call
          link = context.membership.organization_link
          context.delivery = HubAPI::Deliveries.find(
            id: context.id, siret: link.siret, insee_code: link.insee_code
          )
        rescue HubAPI::NotFound, HubAPI::InvalidRequest
          # `InvalidRequest` vaut introuvable : seul l'identifiant vient de l'URL, et un robot qui
          # balaie `/demarches/%20` noierait Sentry. `inspect` : contre les faux retours à la ligne.
          Rails.logger.info("Démarche introuvable en amont : #{context.id.inspect}")
          context.fail!(error: :not_found)
        rescue HubAPI::Error => e
          # Journalisé en plus de Sentry : sans DSN, rien ne sortirait.
          Rails.logger.error("Démarches indisponibles — #{e.class} : #{e.message}")
          Sentry.capture_exception(e)
          context.fail!(error: :unavailable)
        end
      end
    end
  end
end
