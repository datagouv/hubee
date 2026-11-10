# frozen_string_literal: true

module API
  class AgentMailer < ApplicationMailer
    def invitation(agent, organization_name:, siret:)
      @agent = agent
      @organization_name = organization_name.presence
      @siret = siret

      mail(to: agent.email)
    end
  end
end
