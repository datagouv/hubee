# frozen_string_literal: true

# La gem vit dans un groupe hors `default` : Bundler ne l'auto-requiert pas.
require "hub_api_v1"

module Portail
  module HubAPI
    # Cette lecture ne porte aucune dimension d'organisation : le cloisonnement est celui de
    # l'appelant. On ne passe ici que le code d'un télédossier déjà servi à l'agent.
    module DataStreams
      # Le paramétrage d'un flux bouge très rarement : une heure de retard sur un assouplissement
      # est sans conséquence pour l'agent.
      CACHE_TTL = 1.hour

      # La valeur est sérialisée : un membre ajouté ou retiré, ici ou dans les règles, casse la
      # relecture de ce qui est en cache. La clé porte la forme, le passé se met hors jeu tout seul.
      CACHE_NAMESPACE = "portail/data_stream/#{Portail::DataStream.members.join("-")}/" \
        "#{Portail::DataStream::V1Rules.members.join("-")}"

      class << self
        def find(code:, client: HubApiV1.client)
          data_stream_from(HubApiV1::V2::DataStream.find(code: code, client: client))
        rescue HubApiV1::Error => e
          raise HubAPI.translated(e)
        end

        # Deux chemins lisent le flux dans la même requête, et une étape d'interactor ne consomme
        # jamais ce qu'une autre a posé : le cache est leur mémoire commune. `nil` quand le flux ne
        # se lit pas, flux inconnu compris : c'est à chaque usage de décider ce qu'il en fait.
        def fetch(code)
          Rails.cache.fetch([CACHE_NAMESPACE, code], expires_in: CACHE_TTL) do
            find(code: code)
          end
        rescue HubAPI::Error => e
          Rails.logger.error("Flux indisponible — #{e.class} : #{e.message}")
          nil
        end

        private

        # Symbols en amont, String dans le portail : la conversion vit ici seulement, comme pour
        # l'état d'un télédossier.
        def data_stream_from(data_stream)
          Portail::DataStream.new(
            code: data_stream.code,
            name: data_stream.name,
            allowed_states: data_stream.allowed_states.map(&:to_s),
            v1: v1_rules_from(data_stream.v1)
          )
        end

        def v1_rules_from(rules)
          Portail::DataStream::V1Rules.new(
            attachment_states: rules.attachment_states.map(&:to_s),
            attachment_content_types: rules.attachment_content_types,
            attachment_max_byte_size: rules.attachment_max_byte_size
          )
        end
      end
    end
  end
end
