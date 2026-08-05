# frozen_string_literal: true

module Portail
  # Qui doit présenter un second facteur, et sa session l'a-t-elle fait. La règle ne peut pas
  # vivre sur Membership : un modèle AR de `::` ne porte pas de logique d'un seul module.
  module SecondFactor
    # Parmi les niveaux qu'accepte déjà CheckAuthenticationLevel, ceux qui attestent un
    # second facteur — `eidas1` seul est mono-facteur.
    LEVELS = %w[eidas1-mfa eidas2 eidas3].freeze

    module_function

    def required_for?(membership)
      membership.local_administrator? || sensitive_habilitation?(membership)
    end

    def satisfied?(membership, acr)
      return true unless required_for?(membership)

      LEVELS.include?(acr)
    end

    def sensitive_habilitation?(membership)
      return false if SensitiveProcesses::CODES.empty?

      membership.process_accesses
        .where("UPPER(process_code) IN (?)", SensitiveProcesses::CODES)
        .exists?
    end
  end
end
