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

    # N'a de sens que sur une session accordée : un refus n'a pas de rattachement, et
    # l'appelant s'en assure.
    def satisfied?(provider_session)
      return true unless required_for?(provider_session.membership)

      LEVELS.include?(provider_session.acr)
    end

    def sensitive_habilitation?(membership)
      return false if SensitiveProcesses::CODES.empty?

      membership.process_accesses
        .where("UPPER(process_code) IN (?)", SensitiveProcesses::CODES)
        .exists?
    end
  end
end
