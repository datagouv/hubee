# frozen_string_literal: true

module Portail
  module Deliveries
    class Index
      # Ce que l'agent peut choisir comme flux, et ce qu'il a demandé : on ne demande que parmi
      # ce qui est sélectionnable.
      class ResolveDataStreams
        include Interactor

        # Les abonnements d'une structure bougent rarement, mais un abonnement ajouté doit se voir
        # dans la foulée : un appel par structure et par dix minutes.
        CACHE_TTL = 10.minutes

        def call
          # Un périmètre vide ne part jamais en aval : une liste de codes vide y vaut
          # « aucun filtre », donc toute l'organisation.
          context.fail!(error: :no_habilitation) if Access::ProcessPerimeter.none?(membership)

          context.selectable_data_streams = selectable_data_streams
          context.requested_data_streams = requested_data_streams
        end

        private

        def membership = context.membership

        # Les habilitations du rattachement, ou les abonnements de l'organisation quand rien ne le
        # restreint. Transitoire : le temps que les administrateurs locaux reçoivent leurs
        # habilitations par flux comme les agents, la seconde branche disparaîtra.
        def selectable_data_streams
          return membership.process_codes.sort unless Access::ProcessPerimeter.unrestricted?(membership)

          organisation_data_streams
        end

        # Le couple vient du rattachement : pris ailleurs, il ouvrirait une autre structure.
        def organisation_data_streams
          link = membership.organization_link
          Rails.cache.fetch(["portail", "data_streams", link.siret, link.insee_code], expires_in: CACHE_TTL) do
            HubAPI::Subscriptions.list(siret: link.siret, insee_code: link.insee_code).portal_data_stream_codes
          end
        rescue HubAPI::Error => e
          # L'incident est déjà signalé par Portail::HubAPI : il ne reste qu'à journaliser et à échouer.
          Rails.logger.error("Flux indisponibles — #{e.class} : #{e.message}")
          context.fail!(error: :unavailable)
        end

        # Le flux choisi, s'il est sélectionnable ; sans choix, le périmètre lui-même.
        def requested_data_streams
          chosen = context.criteria.data_stream_code
          return Access::ProcessPerimeter.filter(membership) if chosen.nil?
          return [chosen] if context.selectable_data_streams.include?(chosen)

          Rails.logger.info("Flux hors des flux sélectionnables — #{chosen.inspect}")
          context.fail!(error: :invalid_request)
        end
      end
    end
  end
end
