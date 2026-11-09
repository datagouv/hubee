# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        class Create
          # Un agent invité est un agent créé par un appel qui l'a demandé : ni un rejeu, ni un agent
          # déjà connu rattaché à une autre organisation.
          class EnqueueInvitation
            include Interactor

            def call
              return unless context.agent_created && form.send_invitation

              enqueue
            end

            private

            def form = context.form

            # L'agent est enregistré : une file indisponible ne doit pas changer la réponse.
            def enqueue
              InviteAgentJob.perform_later(
                context.membership.agent,
                organization_name: context.organization_name, siret: form.siret, insee_code: form.insee_code,
                api_client: context.api_client.name, api_client_uid: context.api_client.uid, request_id: context.request_id
              )
            rescue => e
              Rails.error.report(e, handled: true)
            end
          end
        end
      end
    end
  end
end
