# frozen_string_literal: true

module Portail
  module Authentication
    extend ActiveSupport::Concern

    included do
      helper_method :current_agent, :agent_signed_in?, :current_membership, :current_organization_link
    end

    private

    def current_agent
      current_membership&.agent
    end

    # Relu à chaque requête plutôt que porté par le cookie : le cookie_store est
    # auto-porté et ne peut pas être révoqué côté serveur. Retirer un rattachement ferme
    # donc l'accès dès la requête suivante.
    def current_membership
      return unless session[:membership_id]

      @current_membership ||= Membership.find_by(id: session[:membership_id])
    end

    def current_organization_link
      current_membership&.organization_link
    end

    def agent_signed_in?
      current_agent.present?
    end
  end
end
