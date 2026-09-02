# frozen_string_literal: true

module API
  module Agents
    class Create
      class FindOrCreateOrganizationLinks
        include Interactor

        # Le référentiel n'est interrogé que si le lien n'existe pas : la dépendance
        # réseau ne pèse que sur le premier agent d'une organisation. Un seul
        # rattachement en échec fait échouer tout l'appel — pas d'écriture partielle.
        def call
          current_membership = nil
          current_index = nil
          context.organization_links = payload.memberships.each_with_index.each_with_object({}) do |(membership, index), links|
            current_membership = membership
            current_index = index
            links[membership.siret] = existing_link(membership) || create_verified_link(membership)
          end
        rescue Referential::Organization::NotFound
          context.fail!(error: :organization_unknown, membership_index: current_index)
        rescue Referential::Organization::Inconsistent => e
          # Donnée corrompue en amont : un humain doit corriger, réessayer redonnera le même
          # doublon. Pour l'appelant, indistinct d'une panne.
          Rails.error.report(e, handled: true,
            context: {siret: current_membership.siret, insee_code: current_membership.insee_code})
          context.fail!(error: :referential_unavailable)
        rescue Referential::Organization::Unavailable => e
          # Panne : le journal suffit — un événement de supervision par appel noierait l'alerte.
          Rails.logger.error(
            "Referential unavailable for #{current_membership.siret}/#{current_membership.insee_code}: #{e.cause&.class}"
          )
          context.fail!(error: :referential_unavailable)
        end

        private

        def payload
          context.payload
        end

        def existing_link(membership)
          OrganizationLink.find_by(siret: membership.siret, insee_code: membership.insee_code)
        end

        def create_verified_link(membership)
          Referential::Organization.find(siret: membership.siret, insee_code: membership.insee_code)
          # Savepoint : sans lui, la violation d'unicité avorterait la transaction de
          # l'organizer et la récupération du lien concurrent lèverait au lieu de lire.
          ActiveRecord::Base.transaction(requires_new: true) do
            OrganizationLink.create!(siret: membership.siret, insee_code: membership.insee_code)
          end
        rescue ActiveRecord::RecordNotUnique
          # Un appel concurrent vient de créer le lien : le référentiel a déjà confirmé.
          existing_link(membership)
        end
      end
    end
  end
end
