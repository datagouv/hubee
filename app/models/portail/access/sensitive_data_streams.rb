# frozen_string_literal: true

module Portail
  module Access
    # Les flux dont l'accès exige un second facteur. La liste n'est pas dans ce dépôt,
    # qui est public : elle est injectée par l'environnement depuis ansible_deploy.
    # Sa présence est exigée au démarrage par config/initializers/sensitive_data_streams.rb.
    module SensitiveDataStreams
      class << self
        # Majuscules des deux côtés de la comparaison : les codes sont stockés verbatim, et une
        # divergence de casse ferait échapper un agent au second facteur en silence.
        def parse(raw)
          raw.to_s.split(",").map { |code| code.strip.upcase }.reject(&:empty?).freeze
        end
      end

      # Déclarée après `parse`, qui la construit.
      CODES = parse(ENV.fetch("SENSITIVE_DATA_STREAM_CODES", ""))
    end
  end
end
