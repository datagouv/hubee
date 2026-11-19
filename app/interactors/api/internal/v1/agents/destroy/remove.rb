# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        class Destroy
          # Une suppression sans sa trace n'a pas lieu : tout se fait dans une seule transaction.
          class Remove
            include Interactor

            # Les rattachements partent par `dependent: :destroy`, leurs habilitations et leurs sessions par la
            # cascade en base. Les liens d'organisation restent : ils servent à d'autres agents. Les traces
            # antérieures de l'agent aussi, un événement n'ayant aucune clé étrangère vers son objet.
            #
            # Le verrou vient en premier : il fait attendre un rattachement ou une modification simultanés (une
            # clé étrangère refuserait sinon la suppression d'un agent qui vient d'être rattaché), et recharge
            # l'agent pour que la trace décrive l'état supprimé, non celui lu au début de la requête.
            def call
              ActiveRecord::Base.transaction do
                agent.lock!
                Event.create!(eventable: agent, event_type: "agent.deleted", metadata:)
                agent.destroy!
              end
            end

            private

            def agent = context.agent

            # Écrites avant la suppression : après elle, l'agent n'est plus lisible. L'adresse et, par
            # rattachement, le SIRET et le code INSEE disent encore à qui l'accès appartenait.
            def metadata
              {
                api_client: context.api_client.name,
                api_client_uid: context.api_client.uid,
                request_id: context.request_id,
                email: agent.email,
                memberships: memberships_metadata
              }
            end

            # Triés : la trace se relit et se compare sans dépendre de l'ordre de lecture. Le verrou a vidé les
            # rattachements préchargés par le controller : ils sont relus avec leur organisation et leurs
            # habilitations, et verrouillés après l'agent, dans l'ordre de toute écriture. Une modification
            # simultanée d'un rattachement attend ainsi la suppression, au lieu de changer ce que la trace décrit.
            def memberships_metadata
              agent.memberships.lock.includes(:organization_link, :data_stream_accesses)
                .map { membership_metadata(it) }.sort_by { [it[:siret], it[:insee_code]] }
            end

            def membership_metadata(membership)
              {
                siret: membership.organization_link.siret,
                insee_code: membership.organization_link.insee_code,
                role: membership.role,
                data_stream_codes: membership.data_stream_codes.sort
              }
            end
          end
        end
      end
    end
  end
end
