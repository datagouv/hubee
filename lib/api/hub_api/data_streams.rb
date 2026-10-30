# frozen_string_literal: true

# La gem vit dans un groupe hors `default` : Bundler ne l'auto-requiert pas.
require "hub_api_v1"

module API
  module HubAPI
    module DataStreams
      # Seule une reconnaissance se garde : un refus ou une panne n'est jamais mis en cache.
      CACHE_TTL = 1.hour

      class << self
        # L'API ne lit pas les règles du flux : elle veut seulement savoir que hub-api le connaît.
        def verify(code:, client: HubApiV1.client)
          Rails.cache.fetch(["api/known_data_stream", code], expires_in: CACHE_TTL) do
            found = HubApiV1::V2::DataStream.find(code:, client:).code
            # Un code est opaque : un autre code rendu, même à la casse près, ne vaut pas celui demandé.
            # Le refus reste celui d'un code inconnu ; le journal garde trace d'un changement de hub-api.
            unless found == code
              message = "hub-api désigne « #{found} » pour « #{code} »"
              Rails.logger.warn(message)
              raise NotFound, message
            end

            true
          end
        # Levée sur « . » ou « .. », que la gem refuse de placer dans un chemin : aucun flux ne s'appelle ainsi.
        rescue HubApiV1::InvalidArgumentError => e
          raise NotFound, e.message
        rescue HubApiV1::Error => e
          raise HubAPI.translated(e)
        end
      end
    end
  end
end
