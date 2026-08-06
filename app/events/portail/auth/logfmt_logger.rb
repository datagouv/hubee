# frozen_string_literal: true

module Portail
  module Auth
    # Format attendu par le CSIRT. L'adresse et l'identifiant pseudonyme sont masqués ici et
    # conservés dans la table : deux abonnés, deux politiques sur la même décision.
    class LogfmtLogger
      MASKED = %i[email provider_sub].freeze

      def emit(event)
        # Le nom en tête donne au CSIRT de quoi isoler ces lignes dans un flux de journaux.
        # Pris de l'événement : pas de second nom à tenir à jour.
        fields = {event: event[:name]}
          .merge(event[:payload].to_h.except(*MASKED))
          .merge(event[:context].to_h)

        Rails.logger.info(fields.compact.map { |name, value| "#{name}=#{value.inspect}" }.join(" "))
      end
    end
  end
end
