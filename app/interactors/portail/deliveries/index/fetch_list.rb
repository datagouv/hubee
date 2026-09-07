# frozen_string_literal: true

module Portail
  module Deliveries
    class Index
      class FetchList
        include Interactor

        PER_PAGE = 25

        def call
          # Un périmètre vide ne part jamais en aval : une liste de codes vide y vaut
          # « aucun filtre », donc toute l'organisation.
          context.fail!(error: :no_habilitation) if Access::ProcessPerimeter.none?(context.membership)

          context.deliveries, context.page = fetch
        end

        private

        # La requête est bornée par le rattachement ; ce que l'amont renvoie est ensuite borné
        # par la policy, qui ne lui fait pas confiance.
        def fetch
          link = context.membership.organization_link
          HubAPI::Deliveries.list(
            siret: link.siret, insee_code: link.insee_code, state: context.state,
            data_stream_codes: Access::ProcessPerimeter.filter(context.membership),
            page: context.page, per_page: PER_PAGE
          )
        rescue HubAPI::InvalidRequest => e
          # `inspect` : le message amont cite le paramètre refusé, qui vient de l'URL.
          Rails.logger.info("Filtre de démarches refusé — #{e.message.inspect}")
          context.fail!(error: :invalid_request)
        rescue HubAPI::Error => e
          # L'incident est déjà signalé par Portail::HubAPI, qui a traduit la panne : il ne
          # reste qu'à la journaliser et à échouer.
          Rails.logger.error("Démarches indisponibles — #{e.class} : #{e.message}")
          context.fail!(error: :unavailable)
        end
      end
    end
  end
end
