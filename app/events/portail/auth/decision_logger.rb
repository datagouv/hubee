# frozen_string_literal: true

module Portail
  module Auth
    # Écrit la décision pour le CSIRT. Les champs partent en payload et non composés dans le
    # message : c'est le formateur logfmt de l'appender qui sérialise, et chaque champ ressort
    # au premier niveau de la ligne. L'adresse et l'identifiant pseudonyme sont masqués ici et
    # conservés dans la table : deux abonnés, deux politiques sur la même décision.
    class DecisionLogger
      MASKED = %i[email provider_sub].freeze

      def emit(event)
        # Le nom en tête donne au CSIRT de quoi isoler ces lignes. Pris de l'événement : pas
        # de second nom à tenir à jour.
        fields = {event: event[:name]}
          .merge(event[:payload].to_h.except(*MASKED))
          .merge(event[:context].to_h)

        Rails.logger.info("Décision d'accès", fields.compact)
      end
    end
  end
end
