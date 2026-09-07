# frozen_string_literal: true

module Portail
  module Access
    # L'organisation qu'un rattachement a le droit de lire, confrontée à ce que l'amont a servi.
    # La requête amont porte déjà l'organisation ; ici on vérifie qu'il l'a respectée.
    module OrganizationPerimeter
      module_function

      # Un SIRET seul ne désigne pas une organisation : plusieurs peuvent le porter, seul le
      # code INSEE les sépare.
      def covers?(membership, recipient)
        link = membership.organization_link
        recipient.siret == link.siret && recipient.insee_code == link.insee_code
      end
    end
  end
end
