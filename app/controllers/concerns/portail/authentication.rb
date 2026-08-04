# frozen_string_literal: true

module Portail
  module Authentication
    extend ActiveSupport::Concern

    # Toucher l'enregistrement à chaque requête serait inutilement coûteux : sur une borne
    # de trente minutes, une granularité d'une minute ne change rien.
    TOUCH_THROTTLE = 1.minute

    included do
      helper_method :current_agent, :agent_signed_in?, :current_membership
      before_action :expire_stale_session!
      before_action :require_authentication
    end

    class_methods do
      # Fermé par défaut : un contrôleur ajouté demain l'est aussi, sauf déclaration ici.
      def allow_unauthenticated_access(**options)
        skip_before_action :require_authentication, **options
      end
    end

    private

    def require_authentication
      return if agent_signed_in?

      # Un chemin, jamais une URL ni un paramètre : sinon on ouvre une redirection
      # arbitraire. Consultation seulement — rejouer un POST après connexion n'aurait pas
      # de sens. HEAD est inclus : c'est un GET sans corps, et `request.get?` l'exclut.
      session[:return_to] = request.fullpath if request.get? || request.head?
      redirect_to root_path
    end

    # À lire avant `start_new_session_for`, dont le reset_session efface la destination.
    def after_authentication_url
      session.delete(:return_to) || root_path
    end

    # `granted` seulement : un refus laisse aussi un enregistrement, qui n'ouvre rien.
    def find_session_by_cookie
      session[:provider_session_id] &&
        ProviderSession.granted.find_by(id: session[:provider_session_id])
    end

    # reset_session AVANT de poser l'identité : protection contre la session fixation.
    def start_new_session_for(membership, id_token:, amr:)
      reset_session
      Current.provider_session = ProviderSession.create!(
        membership:, provider_id_token: id_token, amr:, email: membership.agent.email,
        ip_address: request.remote_ip, user_agent: request.user_agent
      )
      session[:provider_session_id] = Current.provider_session.id
    end

    def terminate_session
      Current.provider_session&.destroy
      Current.provider_session = nil
      reset_session
    end

    def expire_stale_session!
      record = find_session_by_cookie
      return unless record

      Current.provider_session = record
      return close_expired_session! if Portail::SessionLifetime.expired?(record)

      record.touch if record.updated_at < TOUCH_THROTTLE.ago
    end

    # Détruire plutôt qu'oublier le cookie : une session expirée ne doit pas figurer dans
    # un inventaire des sessions ouvertes.
    def close_expired_session!
      terminate_session
      flash.now[:alert] = t("portail.sessions.expired")
    end

    # Relu à chaque requête plutôt que porté par le cookie : retirer un rattachement ferme
    # l'accès dès la requête suivante.
    def current_membership = Current.membership

    def current_agent = Current.agent

    def agent_signed_in? = Current.agent.present?
  end
end
