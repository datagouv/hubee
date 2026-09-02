# frozen_string_literal: true

module Portail
  module Access
    # Ce qu'un rattachement a le droit de lire. Des habilitations renseignées bornent tout le
    # monde, administrateur local compris ; le rôle ne tranche que la liste vide.
    module ReadingPerimeter
      # Levée par `filter` sur un périmètre sans accès : transmis à l'amont, un filtre vide vaut
      # « aucun filtre », soit toute l'organisation.
      class NoAccess < StandardError; end

      module_function

      def covers?(membership, code)
        membership.process_codes.include?(code) || unrestricted?(membership)
      end

      # Ce que l'amont attend : une liste de flux, vide quand rien ne restreint la lecture.
      def filter(membership)
        raise NoAccess if none?(membership)

        membership.process_codes
      end

      def none?(membership) = membership.process_codes.empty? && !membership.local_administrator?

      def unrestricted?(membership) = membership.process_codes.empty? && membership.local_administrator?
    end
  end
end
