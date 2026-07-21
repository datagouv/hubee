# frozen_string_literal: true

module Portail
  module Authentication
    extend ActiveSupport::Concern

    included do
      helper_method :current_agent, :agent_signed_in?
    end

    private

    def current_agent
      return unless session[:agent_id]

      @current_agent ||= Agent.find_by(id: session[:agent_id])
    end

    def agent_signed_in?
      current_agent.present?
    end
  end
end
