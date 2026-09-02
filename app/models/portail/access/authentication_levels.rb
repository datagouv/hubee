# frozen_string_literal: true

module Portail
  module Access
    # Le vocabulaire `acr` de ProConnect et ce que le portail en fait : ce qu'on exige au
    # départ, ce qu'on accepte au retour, ce qui vaut second facteur.
    module AuthenticationLevels
      # Au niveau 0, le lien organisationnel est déclaratif — y compris avec MFA : le refus
      # porte sur le niveau, jamais sur l'absence de second facteur (`eidas0-mfa` est aussi
      # déclaratif qu'`eidas0`).
      MINIMUM = "eidas1"

      # Ceux qui attestent un second facteur. `eidas1` seul est mono-facteur.
      SECOND_FACTOR = %w[eidas1-mfa eidas2 eidas3].freeze

      # Dérivé, jamais recopié.
      ACCEPTED = [MINIMUM, *SECOND_FACTOR].freeze

      module_function

      # Une élévation n'accepte plus le plancher : la requête serait contradictoire.
      def demanded(step_up:) = step_up ? SECOND_FACTOR : [MINIMUM]

      def accepted?(acr) = ACCEPTED.include?(acr)

      def second_factor?(acr) = SECOND_FACTOR.include?(acr)
    end
  end
end
