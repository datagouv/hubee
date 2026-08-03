# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      class FindMembership
        include Interactor

        # Aucun appel V1 ici : une indisponibilité du référentiel ne doit pas empêcher les
        # connexions.
        def call
          context.membership = context.agent
            .memberships
            .joins(:organization_link)
            .find_by(organization_links: {siret: context.siret})

          context.fail!(error: :organization_mismatch) if context.membership.nil?
        end
      end
    end
  end
end
