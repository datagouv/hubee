# frozen_string_literal: true

module Portail
  module Deliveries
    class Index
      class FetchList
        include Interactor

        PER_PAGE = 25

        def call
          context.list = fetch
        end

        private

        def criteria = context.criteria

        # La requête est bornée par le filtre résolu à l'étape précédente ; ce que l'amont
        # renvoie est ensuite borné par la policy, qui ne lui fait pas confiance.
        def fetch
          link = context.membership.organization_link
          HubAPI::Deliveries.list(
            siret: link.siret, insee_code: link.insee_code, state: criteria.state,
            data_stream_codes: context.requested_data_streams,
            transmitted_from: criteria.transmitted_from, transmitted_to: criteria.transmitted_to,
            sort: criteria.sort, direction: criteria.direction,
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
