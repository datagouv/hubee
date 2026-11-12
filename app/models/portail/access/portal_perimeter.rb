# frozen_string_literal: true

module Portail
  module Access
    # Les flux que l'organisation d'un rattachement reçoit par le portail. Un flux reçu par l'API
    # est traité par le système client de l'organisation : aucun de ses télédossiers ne s'ouvre
    # ici, quels que soient le rôle et les habilitations.
    module PortalPerimeter
      class << self
        # Les abonnements sont lus par le cache de la frontière : une requête ne les demande qu'une
        # fois à l'amont, autant de télédossiers et de questions qu'elle pose. Illisibles, le mode
        # d'accès est inconnu et rien ne s'ouvre : une panne, pas un refus.
        def covers?(membership, data_stream_code)
          link = membership.organization_link
          subscriptions = HubAPI::Subscriptions.fetch(siret: link.siret, insee_code: link.insee_code)
          raise HubAPI::Unavailable, "Abonnements illisibles : mode d'accès des flux inconnu" if subscriptions.nil?

          subscriptions.portal_data_stream_codes.include?(data_stream_code)
        end
      end
    end
  end
end
