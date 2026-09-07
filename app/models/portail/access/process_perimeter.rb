# frozen_string_literal: true

module Portail
  module Access
    # Les flux qu'un rattachement a le droit d'atteindre. Des habilitations renseignées bornent
    # tout le monde, administrateur local compris ; le rôle ne tranche que la liste vide.
    module ProcessPerimeter
      # Levée par `filter` sur un périmètre sans accès : transmis à l'amont, un filtre vide vaut
      # « aucun filtre », soit toute l'organisation.
      class NoAccess < StandardError; end

      module_function

      # Le rôle d'abord : une colonne, avant de parcourir les habilitations.
      def covers?(membership, code)
        unrestricted?(membership) || membership.process_codes.include?(code)
      end

      # Ce que l'amont attend : une liste de flux, vide quand rien ne restreint la lecture. La
      # gem omet alors le paramètre, et l'amont sert toute l'organisation.
      def filter(membership)
        raise NoAccess if none?(membership)

        membership.process_codes
      end

      def none?(membership) = membership.process_codes.empty? && !membership.local_administrator?

      def unrestricted?(membership) = membership.process_codes.empty? && membership.local_administrator?
    end
  end
end
