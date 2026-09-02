# frozen_string_literal: true

module API
  module Agents
    class Create
      class RecordTraces
        include Interactor

        # Dernière étape de la transaction : pas d'habilitation écrite sans sa trace,
        # pas de trace sans son habilitation — une trace par rattachement.
        def call
          Event.record!(context.agent, type: "agent.created", metadata: agent_metadata)
          context.memberships.each do |membership|
            Event.record!(membership, type: "membership.created", metadata: membership_metadata(membership))
          end
        end

        private

        def universal
          {"api_client" => context.api_client, "request_id" => context.request_id}
        end

        # Subject = état d'après complet, valeurs nulles comprises : l'avant reste
        # réservé à `changes` sur les traces de correction.
        def agent_metadata
          universal.merge("subject" => {
            "email" => context.agent.email,
            "first_name" => context.agent.first_name,
            "last_name" => context.agent.last_name,
            "civility" => context.agent.civility
          })
        end

        def membership_metadata(membership)
          universal.merge("subject" => {
            "email" => context.agent.email,
            "siret" => membership.organization_link.siret,
            "insee_code" => membership.organization_link.insee_code,
            "role" => membership.role,
            "job_title" => membership.job_title,
            "phone_number" => membership.phone_number
          })
        end
      end
    end
  end
end
