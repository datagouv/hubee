# frozen_string_literal: true

module Portail
  module Access
    # Réveille quelqu'un quand l'amont n'a pas tenu son contrat : une page servie hors du
    # périmètre demandé est une anomalie de sécurité. Un refus d'habilitation, lui, est un
    # refus qui fonctionne : journalisé, jamais alerté.
    class Alerter
      def emit(event)
        refusal = event[:payload]
        return unless refusal.reason == :upstream_mismatch

        count = refusal.dropped_ids.size
        Sentry.capture_message(
          "Périmètre non respecté par l'amont sur #{refusal.path} : #{count} " \
          "élément#{"s" if count > 1} hors périmètre retiré#{"s" if count > 1} de la page",
          level: :warning,
          extra: {membership_id: refusal.membership_id, dropped_ids: refusal.dropped_ids}
        )
      end
    end
  end
end
