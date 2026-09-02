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
        rescue HubAPI::NotFound
          # `inspect` : l'identifiant vient de l'URL, des retours à la ligne y forgeraient de
          # fausses lignes de journal.
          Rails.logger.info("Démarche introuvable en amont : #{context.id.inspect}")
          context.fail!(error: :not_found)
        rescue HubAPI::Error => e
          # `InvalidRequest` rangé avec les pannes : au détail, un paramètre refusé ne peut venir
          # que de nos données. Journalisé en plus de Sentry : sans DSN, rien ne sortirait.
          Rails.logger.error("Démarches indisponibles — #{e.class} : #{e.message}")
          Sentry.capture_exception(e)
          context.fail!(error: :unavailable)
        end
      end
    end
  end
end
