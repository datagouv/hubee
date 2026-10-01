# frozen_string_literal: true

module Portail
  class Delivery
    # Le texte que l'agent adresse à l'émetteur avec un changement d'état.
    module StateMessage
      MAX_LENGTH = 500

      # Fins de ligne ramenées à `\n` : la borne se compte comme le champ la compte.
      def self.of(param)
        return unless param.is_a?(String)

        param.gsub("\r\n", "\n").strip.presence
      end
    end
  end
end
