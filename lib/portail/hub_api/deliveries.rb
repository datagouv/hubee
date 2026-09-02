# frozen_string_literal: true

# La gem vit dans un groupe hors `default` : Bundler ne l'auto-requiert pas.
require "hub_api_v1"

module Portail
  module HubAPI
    # Les démarches, traduites dans les deux sens : entrées vers les mots-clés de la gem,
    # sorties en modèles du portail, erreurs en erreurs de Portail::HubAPI.
    module Deliveries
      class << self
        def list(siret:, insee_code:, state:, data_stream_codes:, page:, per_page:,
          client: HubApiV1.client)
          page_of(
            HubApiV1::V2::Delivery.list(
              siret: siret,
              code_insee: insee_code,
              # String dans le portail, Symbol en amont : la conversion vit ici seulement.
              state: state.to_sym,
              data_stream_codes: data_stream_codes,
              offset: offset_for(page, per_page),
              per_page: per_page,
              client: client
            )
          )
        rescue HubApiV1::Error => e
          raise translated(e)
        end

        def find(id:, siret:, insee_code:, client: HubApiV1.client)
          delivery_from(
            HubApiV1::V2::Delivery.find(id: id, siret: siret, code_insee: insee_code, client: client)
          )
        rescue HubApiV1::Error => e
          raise translated(e)
        end

        private

        # `to_i` : la page peut arriver en String. Trafiquée, elle donne 0, donc un décalage
        # négatif que l'amont refuse.
        def offset_for(page, per_page) = (page.to_i - 1) * per_page

        def page_of(list)
          Portail::Delivery::List.new(
            deliveries: list.deliveries.map { |summary| summary_from(summary) },
            pagination: pagination_from(list.pagination),
            # `transform_keys` préserve l'ordre des états.
            counts_by_state: list.counts_by_state.transform_keys(&:to_s)
          )
        end

        def summary_from(summary)
          Portail::Delivery::Summary.new(
            id: summary.id,
            number: summary.number,
            state: summary.state.to_s,
            data_stream: data_stream_from(summary.data_stream),
            transmitted_at: summary.transmitted_at,
            updated_at: summary.updated_at
          )
        end

        def delivery_from(delivery)
          Portail::Delivery.new(
            id: delivery.id,
            number: delivery.number,
            state: delivery.state.to_s,
            data_stream: data_stream_from(delivery.data_stream),
            transmitted_at: delivery.transmitted_at,
            updated_at: delivery.updated_at,
            applicant: applicant_from(delivery.data_package&.applicant),
            # Les pièces du dépôt seulement : celles d'un event restent sur lui, l'écran montre
            # leur provenance.
            attachments: attachments_from(delivery.data_package&.attachments),
            events: delivery.events.map { |event| event_from(event) }
          )
        end

        # `Array()` : le paquet de données peut manquer entièrement.
        def attachments_from(attachments)
          Array(attachments).map { |attachment| attachment_from(attachment) }
        end

        def attachment_from(attachment)
          Portail::Delivery::Attachment.new(
            id: attachment.id,
            filename: attachment.filename,
            content_type: attachment.content_type,
            byte_size: attachment.byte_size,
            kind: attachment.kind,
            state: attachment.state.to_s
          )
        end

        def event_from(event)
          Portail::Delivery::Event.new(
            id: event.id,
            event_type: event.event_type.to_s,
            created_at: event.created_at,
            author: event.author,
            content: event.content,
            si_comment: event.si_comment,
            metadata: metadata_from(event.metadata),
            attachments: attachments_from(event.attachments)
          )
        end

        # `transform_values` et non une liste de clés : l'amont peut ajouter une metadata sans
        # nous prévenir. Ce qui n'est pas un Symbol traverse intact.
        def metadata_from(metadata)
          metadata.transform_values { |value| value.is_a?(Symbol) ? value.to_s : value }
        end

        def data_stream_from(data_stream) = Portail::DataStream.new(code: data_stream.code)

        def applicant_from(applicant)
          return if applicant.nil?

          Portail::Delivery::Applicant.new(first_name: applicant.first_name, last_name: applicant.last_name)
        end

        def pagination_from(pagination)
          Portail::Pagination.new(
            current_page: pagination.current_page, total_pages: pagination.total_pages,
            total: pagination.total
          )
        end

        # La classe d'origine reste dans le message : c'est elle qui distingue une panne d'un
        # refus au journal.
        def translated(error)
          case error
          when HubApiV1::V2::DeliveryNotFoundError then NotFound.new(error.message)
          when HubApiV1::V2::InvalidArgumentError then InvalidRequest.new(error.message)
          else Unavailable.new("#{error.class} : #{error.message}")
          end
        end
      end
    end
  end
end
