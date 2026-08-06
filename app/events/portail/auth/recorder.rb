# frozen_string_literal: true

module Portail
  module Auth
    # Persiste les décisions d'accès. Ses erreurs sont capturées par EventReporter, qui les
    # remonte à error_reporter : tracer ne doit jamais modifier la décision.
    class Recorder
      # Le reste du contexte — les tags, l'horodatage — n'a pas de colonne.
      CONTEXT_FIELDS = %i[ip_address user_agent request_id].freeze

      def emit(event)
        AccessDecision.create!(
          **event[:payload].to_h,
          **event[:context].to_h.slice(*CONTEXT_FIELDS)
        )
      end
    end
  end
end
