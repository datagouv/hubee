# frozen_string_literal: true

module Portail
  module Memberships
    class Index
      # Le nom de chaque flux, et ceux que l'organisation reçoit : de quoi signaler une
      # habilitation hors abonnement.
      class ResolveDataStreams
        include Interactor

        # Une information d'affichage : sans les abonnements, les codes seuls, la page est servie.
        # `subscribed_data_stream_codes` reste nil : rien n'a été vérifié, rien n'est signalé.
        # Le couple vient du rattachement : pris ailleurs, il ouvrirait une autre structure.
        def call
          link = context.membership.organization_link
          subscriptions = HubAPI::Subscriptions.fetch(siret: link.siret, insee_code: link.insee_code)
          context.data_stream_names = subscriptions ? subscriptions.data_stream_names : {}
          context.subscribed_data_stream_codes = subscriptions&.data_stream_codes
        end
      end
    end
  end
end
