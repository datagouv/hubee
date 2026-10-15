# frozen_string_literal: true

module Portail
  # Les champs d'un abonnement à l'écran, avec leur repli.
  module SubscriptionsHelper
    # nil : canal non renseigné, des abonnements inactifs en ont en production. Une valeur inconnue
    # n'arrive pas jusqu'ici, la gem la refuse.
    def subscription_access_mode(subscription)
      return DeliveriesHelper::MISSING if subscription.access_mode.nil?

      t("portail.subscriptions.access_modes.#{subscription.access_mode}")
    end

    # Actif : l'organisation reçoit les télédossiers du flux (read_package).
    def subscription_activity(subscription)
      if subscription.read_package
        tag.p(t("portail.subscriptions.activity.active"), class: "fr-badge fr-badge--sm fr-badge--success")
      else
        tag.p(t("portail.subscriptions.activity.inactive"), class: "fr-badge fr-badge--sm")
      end
    end
  end
end
