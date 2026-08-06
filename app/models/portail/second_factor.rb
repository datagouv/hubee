# frozen_string_literal: true

module Portail
  # Qui doit présenter un second facteur, et sa session l'a-t-elle fait. La règle ne peut pas
  # vivre sur Membership : un modèle AR de `::` ne porte pas de logique d'un seul module.
  module SecondFactor
    module_function

    def required_for?(membership)
      membership.local_administrator? || sensitive_habilitation?(membership)
    end

    def satisfied?(membership, acr)
      return true unless required_for?(membership)

      AuthenticationLevels.second_factor?(acr)
    end

    def sensitive_habilitation?(membership)
      return false if SensitiveProcesses::CODES.empty?

      membership.process_accesses
        .where("UPPER(process_code) IN (?)", SensitiveProcesses::CODES)
        .exists?
    end
  end
end
