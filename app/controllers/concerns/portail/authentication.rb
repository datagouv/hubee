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

    # À lire avant `adopt_session`, dont le reset_session efface la destination.
    def after_authentication_url
      session.delete(:return_to) || root_path
    end

    # Ce que ce navigateur détient, accordé ou refusé. Un refus laisse lui aussi un
    # enregistrement : il n'ouvre rien, mais il doit pouvoir être relu puis abandonné.
    def find_session_by_cookie
      return @session_in_cookie if defined?(@session_in_cookie)

      @session_in_cookie = ProviderSession.find_by(id: session[:provider_session_id])
    end

    # Le métier a produit l'enregistrement, accordé ou refusé ; il reste à en ranger
    # l'identifiant dans le cookie. `terminate_session` plutôt qu'un simple `reset_session` :
    # ouvrir une authentification ferme ce que ce navigateur détenait déjà — protection
    # contre la fixation de session, et une tentative abandonnée ne survit pas jusqu'à la
    # purge avec son jeton.
    def adopt_session(provider_session)
      terminate_session
      session[:provider_session_id] = provider_session.id
    end

    def terminate_session
      find_session_by_cookie&.destroy
      @session_in_cookie = nil
      Current.provider_session = nil
      reset_session
    end

    def expire_stale_session!
      record = find_session_by_cookie
      # Un refus n'est pas une session ouverte : ni la borne d'inactivité ni le message
      # d'expiration ne le concernent.
      return unless record&.granted?

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
