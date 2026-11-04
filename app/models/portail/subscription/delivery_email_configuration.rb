# frozen_string_literal: true

module Portail
  class Subscription
    # Les courriels qu'un abonnement fait envoyer à chaque télédossier ou en récapitulatif : la
    # fréquence, en String comme l'état d'un télédossier, et les adresses telles que l'amont les
    # conserve, même quand aucun courriel ne part.
    class DeliveryEmailConfiguration < Data.define(:frequency, :recipients)
      NO_EMAIL = "none"

      # Seule la fréquence « aucun » l'exclut : une fréquence inconnue ne permet pas d'affirmer
      # qu'aucun courriel ne part.
      def sends_emails? = frequency != NO_EMAIL
    end
  end
end
