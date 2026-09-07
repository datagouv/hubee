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
          not_found(:unknown)
        rescue HubAPI::InvalidRequest
          # Vaut introuvable : seul l'identifiant vient de l'URL, un robot qui balaie
          # `/demarches/%20` ne doit rien déclencher de plus.
          not_found(:invalid_id)
        rescue HubAPI::Error => e
          unavailable(e)
        end

        private

        # En champs, pas dans le message : l'identifiant se filtre au journal, et `reason` sépare
        # l'UUID que l'amont ne connaît pas du bruit des identifiants malformés.
        def not_found(reason)
          Rails.logger.info("Démarche introuvable en amont", id: context.id, reason:)
          context.fail!(error: :not_found)
        end

        # L'incident est déjà signalé par Portail::HubAPI, qui a traduit la panne : il ne reste
        # qu'à la journaliser et à échouer.
        def unavailable(error)
          Rails.logger.error("Démarches indisponibles — #{error.class} : #{error.message}")
          context.fail!(error: :unavailable)
        end
      end
    end
  end
end
