# frozen_string_literal: true

module API
  class InviteAgentJob < ApplicationJob
    discard_on ActiveJob::DeserializationError
    # Un 4xx SMTP : le serveur a refusé le message, rien n'est parti.
    retry_on Net::SMTPServerBusy, wait: :polynomially_longer, attempts: 5

    def perform(agent, organization_name:, siret:, insee_code:, api_client:, api_client_uid:, request_id:)
      # Rejoué après une remise réussie (à la main, ou par un worker relancé) : pas de second courriel.
      return if Event.exists?(eventable: agent, event_type: "agent.invited")

      AgentMailer.invitation(agent, organization_name:, siret:).deliver_now
      Event.create!(
        eventable: agent, event_type: "agent.invited",
        metadata: {api_client:, api_client_uid:, request_id:, email: agent.email, siret:, insee_code:}
      )
    end
  end
end
