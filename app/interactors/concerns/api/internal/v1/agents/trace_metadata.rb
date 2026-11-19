# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        # Ce que toute trace de l'espace interne dit de son origine, et la désignation d'un rattachement
        # qui se lit encore une fois l'agent ou le rattachement supprimé. Aucun refus ici : l'étape qui
        # l'inclut garde les siens.
        module TraceMetadata
          extend ActiveSupport::Concern

          private

          # Le client et la requête : la requête relie la trace au journal du client.
          def actor_metadata
            {
              api_client: context.api_client.name,
              api_client_uid: context.api_client.uid,
              request_id: context.request_id
            }
          end

          def membership_reference(membership)
            {
              email: membership.agent.email,
              siret: membership.organization_link.siret,
              insee_code: membership.organization_link.insee_code
            }
          end
        end
      end
    end
  end
end
