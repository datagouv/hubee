# frozen_string_literal: true

module Portail
  module Access
    # Les flux dont l'accès exige un second facteur. La liste n'est pas dans ce dépôt,
    # qui est public : elle est injectée par l'environnement depuis ansible_deploy.
    # Sa présence est exigée au démarrage par config/initializers/sensitive_data_streams.rb.
    module SensitiveDataStreams
      class << self
        # Les codes tels qu'en V1, casse comprise : un code mal écrit n'est sensible pour personne.
        # Aucun contrôle auprès de la V1, pour pouvoir déclarer un code avant sa création.
        def parse(raw)
          raw.to_s.split(",").map(&:strip).reject(&:empty?).freeze
        end
      end

      # Déclarée après `parse`, qui la construit.
      CODES = parse(ENV.fetch("SENSITIVE_DATA_STREAM_CODES", ""))
    end
  end
end
