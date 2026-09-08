# frozen_string_literal: true

# La gem vit dans un groupe hors `default` : Bundler ne l'auto-requiert pas.
require "hub_api_v1"

module Portail
  module HubAPI
    # Les abonnements d'une organisation, traduits en modèles du portail. La gem les sert déjà
    # dans le modèle V2 : permissions et mode d'accès, sans statut.
    module Subscriptions
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

        private

        def subscription_from(subscription)
          Portail::Subscription.new(
            id: subscription.id,
            data_stream: Portail::DataStream.new(code: subscription.data_stream.code),
            read_package: subscription.read_package,
            create_package: subscription.create_package,
            # Symbol en amont, String dans le portail, comme l'état d'une démarche ; un canal
            # non renseigné reste nil, « » ferait croire à une valeur.
            access_mode: subscription.access_mode&.to_s
          )
        end
      end
    end
  end
end
