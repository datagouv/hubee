# frozen_string_literal: true

module Portail
  module Access
    # Qui doit présenter un second facteur, et sa session l'a-t-elle fait. La règle ne peut pas
    # vivre sur Membership : un modèle AR de `::` ne porte pas de logique d'un seul module.
    module SecondFactor
      # Certains fournisseurs d'identité imposent leur propre MFA sans être qualifiés pour
      # l'attester en niveau : l'acr reste eidas1, mais l'amr du jeton vérifié en témoigne.
      MFA_METHOD = "mfa"

      class << self
        def required_for?(membership)
          membership.local_administrator? || sensitive_habilitation?(membership)
        end

        # Attesté par le niveau, ou par la méthode — les deux sortent du même jeton signé.
        def satisfied?(membership, acr:, amr: [])
          return true unless required_for?(membership)

          AuthenticationLevels.second_factor?(acr) || Array(amr).include?(MFA_METHOD)
        end

        private

        # En Ruby, comme la liste : UPPER de PostgreSQL suit la locale de la base, et en locale C il
        # laisse « é » en minuscule. L'agent échapperait alors au second facteur, sans erreur.
        def sensitive_habilitation?(membership)
          return false if SensitiveDataStreams::CODES.empty?

          membership.data_stream_codes.any? { SensitiveDataStreams::CODES.include?(it.upcase) }
        end
      end
    end
  end
end
