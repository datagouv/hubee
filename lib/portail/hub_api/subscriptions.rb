# frozen_string_literal: true

# La gem vit dans un groupe hors `default` : Bundler ne l'auto-requiert pas.
require "hub_api_v1"

module Portail
  module HubAPI
    # Les abonnements d'une organisation, traduits en modèles du portail. La gem les sert déjà
    # dans le modèle V2 : permissions et mode d'accès, sans statut.
    module Subscriptions
      # Les abonnements d'une structure bougent rarement, mais un abonnement ajouté doit se voir
      # dans la foulée : un appel par structure et par dix minutes.
      CACHE_TTL = 10.minutes

      # La valeur est sérialisée : un membre ajouté ou retiré casse la relecture de ce qui est déjà
      # en cache. La clé porte la forme, le passé se met hors jeu tout seul.
      CACHE_NAMESPACE = "portail/subscriptions/#{Portail::Subscription.members.join("-")}"

      class << self
        # Bornée sur le couple, pas sur le seul SIRET, que deux organisations peuvent partager.
        def list(siret:, insee_code:, client: HubApiV1.client)
          Portail::Subscription::List.new(
            subscriptions: HubApiV1::V2::Subscription.list(siret: siret, code_insee: insee_code, client: client)
              .map { |subscription| subscription_from(subscription) }
          )
        rescue HubApiV1::Error => e
          raise HubAPI.translated(e)
        end

        # La liste, lue une fois par structure : `nil` quand l'amont ne répond pas, et chaque usage
        # en décide.
        def fetch(siret:, insee_code:)
          Rails.cache.fetch([CACHE_NAMESPACE, siret, insee_code], expires_in: CACHE_TTL) do
            list(siret: siret, insee_code: insee_code)
          end
        rescue HubAPI::Error => e
          Rails.logger.error("Abonnements indisponibles — #{e.class} : #{e.message}")
          nil
        end

        private

        def subscription_from(subscription)
          Portail::Subscription.new(
            id: subscription.id,
            data_stream: Portail::DataStream::Summary.new(code: subscription.data_stream.code),
            data_stream_name: subscription.data_stream.name,
            read_package: subscription.read_package,
            create_package: subscription.create_package,
            # Symbol en amont, String dans le portail, comme l'état d'un télédossier ; un canal
            # non renseigné reste nil, « » ferait croire à une valeur.
            access_mode: subscription.access_mode&.to_s
          )
        end
      end
    end
  end
end
