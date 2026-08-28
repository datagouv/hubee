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
            data_stream_code: summary.data_stream.code,
            transmitted_at: summary.transmitted_at,
            updated_at: summary.updated_at
          )
        end

        def delivery_from(delivery)
          Portail::Delivery.new(
            id: delivery.id,
            number: delivery.number,
            state: delivery.state.to_s,
            data_stream_code: delivery.data_stream.code,
            transmitted_at: delivery.transmitted_at,
            updated_at: delivery.updated_at,
            applicant: applicant_from(delivery.data_package&.applicant)
          )
        end

        def applicant_from(applicant)
          return if applicant.nil?

          Portail::Applicant.new(first_name: applicant.first_name, last_name: applicant.last_name)
        end

        def pagination_from(pagination)
          Portail::Pagination.new(
            current_page: pagination.current_page, total_pages: pagination.total_pages
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
