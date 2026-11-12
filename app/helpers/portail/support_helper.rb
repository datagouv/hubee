# frozen_string_literal: true

module Portail
  # Adresses publiques où l'agent trouve de l'aide : le support, affiché partout où il est
  # bloqué, et la section Aide du site vitrine, offerte sur toutes les pages. Elles vivent ici
  # plutôt que dans un contrôleur : c'est du contenu, pas du comportement.
  module SupportHelper
    SUPPORT_EMAIL = "support@hubee.numerique.gouv.fr"
    HELP_URL = "https://hubee.numerique.gouv.fr/aide"

    def support_email = SUPPORT_EMAIL

    def help_url = HELP_URL
  end
end
