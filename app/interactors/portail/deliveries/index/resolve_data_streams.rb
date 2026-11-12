# frozen_string_literal: true

module Portail
  module Deliveries
    class Index
      # Ce que l'agent peut choisir comme flux, ce qu'il a demandé, et le nom de chaque flux : on
      # ne demande que parmi ce qui est sélectionnable.
      class ResolveDataStreams
        include Interactor

        def call
          # Deux refus distincts sous le même motif. Celui-ci se sait sans l'amont : ni appel, ni
          # panne qui le masquerait. Le second, plus bas, dépend des abonnements.
          context.fail!(error: :no_habilitation) if Access::DataStreamPerimeter.none?(membership)

          # Sans les abonnements, le mode d'accès des flux est inconnu : rien à proposer, pas de page.
          subscriptions = read_subscriptions
          context.fail!(error: :unavailable) if subscriptions.nil?

          context.data_stream_names = subscriptions.data_stream_names
          context.selectable_data_streams = by_name(selectable_data_streams(subscriptions))
          # Habilité sur les seuls flux reçus par l'API, ou structure qui n'en reçoit aucun par le
          # portail : rien à demander.
          context.fail!(error: :no_habilitation) if context.selectable_data_streams.empty?

          context.requested_data_streams = requested_data_streams
        end

        private

        def membership = context.membership

        # Les abonnements de l'organisation, nil quand l'amont ne répond pas. Le couple vient du
        # rattachement : pris ailleurs, il ouvrirait une autre structure.
        def read_subscriptions
          link = membership.organization_link
          HubAPI::Subscriptions.fetch(siret: link.siret, insee_code: link.insee_code)
        end

        # Les flux que l'organisation reçoit par le portail, bornés par les habilitations du
        # rattachement quand il en a. Un flux reçu par l'API est traité par le système client de
        # l'organisation, pas ici. Transitoire : le temps que les administrateurs locaux reçoivent
        # leurs habilitations par flux comme les agents, la branche sans borne disparaîtra.
        def selectable_data_streams(subscriptions)
          portal = subscriptions.portal_data_stream_codes
          return portal if Access::DataStreamPerimeter.unrestricted?(membership)

          portal.intersection(membership.data_stream_codes)
        end

        # Le filtre n'affiche que les noms : rangés par code, ils se liraient dans le désordre. Sans
        # accent ni casse, comme la liste des abonnements ; le code tient lieu de nom manquant.
        def by_name(codes)
          codes.sort_by { |code| I18n.transliterate(context.data_stream_names[code] || code).downcase }
        end

        # Les flux choisis, s'ils sont tous sélectionnables ; sans choix, tous les sélectionnables.
        def requested_data_streams
          chosen = context.criteria.data_stream_codes
          return context.selectable_data_streams if chosen.empty?

          unknown = chosen - context.selectable_data_streams
          return chosen if unknown.empty?

          Rails.logger.info("Flux hors des flux sélectionnables — #{unknown.inspect}")
          context.fail!(error: :invalid_request)
        end
      end
    end
  end
end
