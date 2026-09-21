# frozen_string_literal: true

module Portail
  module Deliveries
    class Index
      # Ce que l'agent peut choisir comme flux, ce qu'il a demandé, et le nom de chaque flux : on
      # ne demande que parmi ce qui est sélectionnable.
      class ResolveDataStreams
        include Interactor

        def call
          # Un périmètre vide ne part jamais en aval : une liste de codes vide y vaut
          # « aucun filtre », donc toute l'organisation.
          context.fail!(error: :no_habilitation) if Access::DataStreamPerimeter.none?(membership)

          subscriptions = read_subscriptions
          context.selectable_data_streams = selectable_data_streams(subscriptions).sort
          # Une information d'affichage : sans les abonnements, les codes seuls, la page est servie.
          context.data_stream_names = subscriptions ? subscriptions.data_stream_names : {}
          context.requested_data_streams = requested_data_streams
        end

        private

        def membership = context.membership

        # Les abonnements de l'organisation, nil quand l'amont ne répond pas : chaque usage en
        # décide. Le couple vient du rattachement : pris ailleurs, il ouvrirait une autre structure.
        def read_subscriptions
          link = membership.organization_link
          HubAPI::Subscriptions.fetch(siret: link.siret, insee_code: link.insee_code)
        end

        # Les habilitations du rattachement, ou les abonnements de l'organisation quand rien ne le
        # restreint. Transitoire : le temps que les administrateurs locaux reçoivent leurs
        # habilitations par flux comme les agents, la seconde branche disparaîtra. Sans les
        # abonnements, rien à proposer : pas de page.
        def selectable_data_streams(subscriptions)
          return membership.data_stream_codes unless Access::DataStreamPerimeter.unrestricted?(membership)

          context.fail!(error: :unavailable) if subscriptions.nil?
          subscriptions.portal_data_stream_codes
        end

        # Les flux choisis, s'ils sont tous sélectionnables ; sans choix, le périmètre lui-même.
        def requested_data_streams
          chosen = context.criteria.data_stream_codes
          return Access::DataStreamPerimeter.filter(membership) if chosen.empty?

          unknown = chosen - context.selectable_data_streams
          return chosen if unknown.empty?

          Rails.logger.info("Flux hors des flux sélectionnables — #{unknown.inspect}")
          context.fail!(error: :invalid_request)
        end
      end
    end
  end
end
