# frozen_string_literal: true

module API
  class InviteAgentJob < ApplicationJob
    discard_on ActiveJob::DeserializationError
    # Un 4xx SMTP : le serveur a refusé le message, rien n'est parti.
    retry_on Net::SMTPServerBusy, wait: :polynomially_longer, attempts: 5

    def perform(agent, organization_name:, siret:, insee_code:, api_client:, api_client_uid:, request_id:)
      AgentMailer.invitation(agent, organization_name:, siret:).deliver_now
    end
  end
end
