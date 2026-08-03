# frozen_string_literal: true

module Portail
  module Authentication
    extend ActiveSupport::Concern

    # Borne absolue alignée sur la session ProConnect, de 12 heures : plus courte, elle
    # serait sans effet — un clic réauthentifie en silence tant que sa session vit, et
    # `max-age`, qui corrigerait ça, n'est pas implémenté côté ProConnect. Ce que ces
    # bornes garantissent : le rattachement et le niveau sont réévalués à chaque reprise.
    IDLE_TIMEOUT = 30.minutes
    ABSOLUTE_LIFETIME = 12.hours

    included do
      helper_method :current_agent, :agent_signed_in?, :current_membership, :current_organization_link
      before_action :expire_stale_session!
    end

    private

    def expire_stale_session!
      return unless session[:membership_id]

      if session_expired?
        reset_session
        return
      end

      session[:last_seen_at] = Time.current.to_i
    end

    def session_expired?
      started_at = session[:started_at]
      last_seen_at = session[:last_seen_at]
      return true if started_at.nil? || last_seen_at.nil?

      Time.current > Time.zone.at(started_at) + ABSOLUTE_LIFETIME ||
        Time.current > Time.zone.at(last_seen_at) + IDLE_TIMEOUT
    end

    def current_agent
      current_membership&.agent
    end

    # Relu à chaque requête plutôt que porté par le cookie : le cookie_store est
    # auto-porté et ne peut pas être révoqué côté serveur. Retirer un rattachement ferme
    # donc l'accès dès la requête suivante.
    def current_membership
      return @current_membership if defined?(@current_membership)

      @current_membership = session[:membership_id] && Membership.find_by(id: session[:membership_id])
    end

    def current_organization_link
      current_membership&.organization_link
    end

    def agent_signed_in?
      current_agent.present?
    end
  end
end
