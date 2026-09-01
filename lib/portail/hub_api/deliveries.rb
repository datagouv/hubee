# frozen_string_literal: true

# La gem vit dans un groupe hors `default`, que `Bundler.require(*Rails.groups)` n'inclut
# pas : elle n'est jamais auto-requise, et il faut la demander là où on la consomme. Ce
# fichier est le seul endroit du portail qui la consomme.
require "hub_api_v1"

module Portail
  module HubAPI
    # Les démarches, traduites dans les deux sens.
    #
    # Trois canaux, et rien ne doit fuir sur aucun des trois : les entrées partent du
    # vocabulaire du portail vers les mots-clés de la gem, les sorties reviennent en modèles
    # du portail, et les erreurs de la gem sont retraduites en erreurs de Portail::HubAPI.
    module Deliveries
      class << self
        def list(siret:, insee_code:, state:, data_stream_codes:, page:, per_page:, client: nil)
          page_of(
            HubApiV1::V2::Delivery.list(
              siret: siret,
              # Même donnée, deux graphies : la couture vit ici et nulle part ailleurs.
              code_insee: insee_code,
              # L'état est une String partout dans le portail ; le Symbol est la graphie
              # interne de l'amont. La conversion vit ici, dans les deux sens, et nulle part
              # ailleurs. Explicite plutôt que confiée à la tolérance de l'amont : elle
              # accepte aussi une String, mais c'est un détail de son implémentation.
              state: state.to_sym,
              data_stream_codes: data_stream_codes,
              # Le portail compte en pages, l'amont en décalage.
              offset: offset_for(page, per_page),
              per_page: per_page,
              **injected(client)
            )
          )
        rescue HubApiV1::Error => e
          raise translated(e)
        end

        def find(id:, siret:, insee_code:, client: nil)
          delivery_from(
            HubApiV1::V2::Delivery.find(
              id: id, siret: siret, code_insee: insee_code, **injected(client)
            )
          )
        rescue HubApiV1::Error => e
          raise translated(e)
        end

        # La page vide d'un refus décidé avant l'appel — l'agent habilité sur aucun flux.
        # Construite par la gem plutôt qu'à la main : l'ordre et la complétude des compteurs
        # d'états viennent ainsi du même endroit que ceux d'une vraie page.
        def empty_list(per_page:)
          page_of(HubApiV1::V2::DeliveryList.empty(per_page: per_page))
        end

        private

        # `client:` n'est transmis que s'il a été injecté — en spec, ou par le harnais
        # Cucumber. Absent, c'est la gem qui résout le sien, à l'intérieur ; le lui passer à
        # nil le remplacerait par rien et couperait le chemin nominal.
        def injected(client) = client ? {client: client} : {}

        # `to_i` sur un paramètre d'URL absent ou trafiqué donne 0, donc un décalage négatif :
        # non rattrapé ici, c'est l'amont qui refuse et l'agent qui l'apprend.
        def offset_for(page, per_page) = (page.to_i - 1) * per_page

        def page_of(list)
          Portail::DeliveryList.new(
            deliveries: list.deliveries.map { |summary| summary_from(summary) },
            pagination: pagination_from(list.pagination),
            # `transform_keys` préserve l'ordre d'insertion : l'ordre des états, donc celui
            # des onglets à venir, survit à la traduction.
            counts_by_state: list.counts_by_state.transform_keys(&:to_s)
          )
        end

        def summary_from(summary)
          Portail::DeliverySummary.new(
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
            # Les pièces du dépôt seulement. Celles apportées par un event restent sur lui :
            # les fusionner ici perdrait la provenance, qui est précisément ce que l'écran
            # montre — et l'amont tient déjà ces deux magasins séparés.
            attachments: attachments_from(delivery.data_package&.attachments),
            events: delivery.events.map { |event| event_from(event) }
          )
        end

        # `Array()` plutôt qu'un `&.` de plus : le paquet de données peut manquer entièrement,
        # et l'écran compte des pièces — il n'a pas à distinguer « aucune pièce » de « pas de
        # paquet ». Une liste vide dit les deux, sans que personne ait à s'en soucier.
        def attachments_from(attachments)
          Array(attachments).map { |attachment| attachment_from(attachment) }
        end

        def attachment_from(attachment)
          Portail::Attachment.new(
            id: attachment.id,
            filename: attachment.filename,
            content_type: attachment.content_type,
            byte_size: attachment.byte_size,
            kind: attachment.kind,
            # Même couture que l'état d'une démarche : Symbol en amont, String dans le portail.
            state: attachment.state.to_s
          )
        end

        def event_from(event)
          Portail::Event.new(
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

        # La metadata porte des états, en Symbol comme partout en amont. `transform_values` et
        # non une liste de clés connues : l'amont peut ajouter une metadata sans nous prévenir,
        # et une clé oubliée laisserait entrer une graphie que le reste du portail n'emploie
        # pas. Ce qui n'est pas un Symbol — les booléens de `internal` et `bulk` — traverse
        # intact.
        def metadata_from(metadata)
          metadata.transform_values { |value| value.is_a?(Symbol) ? value.to_s : value }
        end

        # Le portail ne lit que le code, mais porte l'objet : à terme la démarche sera un
        # ::Delivery ActiveRecord avec un `belongs_to :data_stream`, et la forme aura déjà bougé.
        def data_stream_from(data_stream) = Portail::DataStream.new(code: data_stream.code)

        def applicant_from(applicant)
          return if applicant.nil?

          Portail::Applicant.new(first_name: applicant.first_name, last_name: applicant.last_name)
        end

        def pagination_from(pagination)
          Portail::Pagination.new(
            current_page: pagination.current_page, total_pages: pagination.total_pages,
            total: pagination.total
          )
        end

        # La classe d'origine est conservée dans le message : l'appelant journalise l'erreur
        # traduite, et sans elle le diagnostic perdrait ce qui distingue une panne d'un refus.
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
