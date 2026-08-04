# frozen_string_literal: true

module Portail
  # Adresse publique du support, affichée partout où l'agent est bloqué. Elle vit ici
  # plutôt que dans un contrôleur : c'est du contenu, pas du comportement.
  module SupportHelper
    SUPPORT_EMAIL = "support@hubee.numerique.gouv.fr"

    def support_email = SUPPORT_EMAIL
  end
end
