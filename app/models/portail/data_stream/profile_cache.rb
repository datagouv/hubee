# frozen_string_literal: true

module Portail
  # Deux chemins lisent ce profil dans la même requête, et une étape d'interactor ne consomme
  # jamais ce qu'une autre a posé : le cache est leur mémoire commune.
  module DataStream::ProfileCache
    # Le paramétrage d'une démarche bouge très rarement : une heure de retard sur un assouplissement
    # est sans conséquence pour l'agent.
    CACHE_TTL = 1.hour

    # La valeur est sérialisée : un membre ajouté ou retiré casse la relecture de ce qui est déjà
    # en cache. La clé porte la forme, le passé se met hors jeu tout seul.
    CACHE_NAMESPACE = "portail/data_stream_profile/#{DataStream::Profile.members.join("-")}"

    class << self
      # `nil` quand le profil ne se lit pas, démarche inconnue comprise : c'est à chaque usage de
      # décider ce qu'il fait d'un profil qu'il ignore.
      def fetch(code)
        Rails.cache.fetch([CACHE_NAMESPACE, code], expires_in: CACHE_TTL) do
          HubAPI::DataStreams.find(code: code)
        end
      rescue HubAPI::Error => e
        Rails.logger.error("Profil de démarche indisponible — #{e.class} : #{e.message}")
        nil
      end
    end
  end
end
