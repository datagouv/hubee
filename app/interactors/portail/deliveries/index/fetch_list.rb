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
          context.fail!(error: :no_habilitation) if context.perimeter.none?

          context.list = fetch
        end

        private

        def fetch
          link = context.membership.organization_link
          HubAPI::Deliveries.list(
            siret: link.siret, insee_code: link.insee_code, state: context.state,
            data_stream_codes: context.perimeter.filter, page: context.page, per_page: PER_PAGE
          )
        rescue HubAPI::InvalidRequest => e
          # Sans alerte : un robot qui balaie des URL noierait Sentry sous des refus normaux.
          # `inspect` : le message amont cite le paramètre refusé, qui vient de l'URL.
          Rails.logger.info("Filtre de démarches refusé — #{e.message.inspect}")
          context.fail!(error: :invalid_request)
        rescue HubAPI::Error => e
          # Journalisé en plus de Sentry : sans DSN, l'exception partirait au néant.
          Rails.logger.error("Démarches indisponibles — #{e.class} : #{e.message}")
          Sentry.capture_exception(e)
          context.fail!(error: :unavailable)
        end
      end
    end
  end
end
