# frozen_string_literal: true

module Portail
  module Access
    # Les flux qu'un rattachement a le droit d'atteindre. Des habilitations renseignées bornent
    # tout le monde, administrateur local compris ; le rôle ne tranche que la liste vide.
    module DataStreamPerimeter
      class << self
        # Le rôle d'abord : une colonne, avant de parcourir les habilitations.
        def covers?(membership, code)
          unrestricted?(membership) || membership.data_stream_codes.include?(code)
        end

        def none?(membership) = membership.data_stream_codes.empty? && !membership.local_administrator?

        def unrestricted?(membership) = membership.data_stream_codes.empty? && membership.local_administrator?
      end
    end
  end
end
