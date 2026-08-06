# frozen_string_literal: true

module Portail
  module Auth
    # Format attendu par le CSIRT. L'adresse et l'identifiant pseudonyme sont masqués ici et
    # conservés dans la table : deux abonnés, deux politiques sur la même décision.
    class LogfmtLogger
      MASKED = %i[email provider_sub].freeze

      def emit(event)
        fields = event[:payload].to_h.except(*MASKED).merge(event[:context].to_h)
        Rails.logger.info(fields.compact.map { |name, value| "#{name}=#{value.inspect}" }.join(" "))
      end
    end
  end
end
