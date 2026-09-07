# frozen_string_literal: true

module Portail
  module Access
    # Réveille quelqu'un : une page servie par l'amont hors du périmètre demandé est une anomalie
    # de sécurité, une tentative d'accès hors périmètre un signal à ne pas laisser au seul journal.
    class Alerter
      def emit(event)
        refusal = event[:payload]

        case refusal.reason
        when :upstream_mismatch then alert_upstream_mismatch(refusal)
        when :out_of_perimeter then alert_out_of_perimeter(refusal)
        end
      end

      private

      def alert_upstream_mismatch(refusal)
        count = refusal.dropped_ids.size
        Sentry.capture_message(
          "Périmètre non respecté par l'amont sur #{refusal.path} : #{count} " \
          "élément#{"s" if count > 1} hors périmètre retiré#{"s" if count > 1} de la page",
          level: :warning,
          extra: {membership_id: refusal.membership_id, dropped_ids: refusal.dropped_ids}
        )
      end

      def alert_out_of_perimeter(refusal)
        Sentry.capture_message(
          "Accès refusé hors périmètre sur #{refusal.path}",
          level: :warning,
          extra: {agent_id: refusal.agent_id, membership_id: refusal.membership_id}
        )
      end
    end
  end
end
