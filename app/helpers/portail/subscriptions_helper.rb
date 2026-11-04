# frozen_string_literal: true

module Portail
  # Les champs d'un abonnement à l'écran, avec leur repli.
  module SubscriptionsHelper
    # nil : canal non renseigné, des abonnements inactifs en ont en production. Une valeur inconnue
    # n'arrive pas jusqu'ici, la gem la refuse. Le tiret sied à une colonne de liste ; le détail
    # passe son propre repli.
    def subscription_access_mode(subscription, missing: DeliveriesHelper::MISSING)
      return missing if subscription.access_mode.nil?

      t("portail.subscriptions.access_modes.#{subscription.access_mode}")
    end

    # Une valeur hors de la table n'arrive pas : la gem rend alors sa sentinelle `unknown`.
    def subscription_email_frequency(configuration)
      t("portail.subscriptions.email_frequencies.#{configuration.frequency}.label")
    end

    # Ce que la fréquence envoie, quand le libellé ne le dit pas déjà ; nil sinon.
    def subscription_email_frequency_hint(configuration)
      t("portail.subscriptions.email_frequencies.#{configuration.frequency}.hint", default: nil)
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
