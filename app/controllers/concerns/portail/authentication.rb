# frozen_string_literal: true

module Portail
  module Authentication
    extend ActiveSupport::Concern

    # Toucher l'enregistrement à chaque requête serait inutilement coûteux : sur une borne
    # de trente minutes, une granularité d'une minute ne change rien.
    TOUCH_THROTTLE = 1.minute

    included do
      helper_method :current_agent, :agent_signed_in?, :current_membership
      before_action :set_event_context
      before_action :expire_stale_session!
      before_action :enforce_second_factor!
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

      # Un chemin, jamais une URL : sinon redirection arbitraire. GET et HEAD seulement —
      # rejouer un POST après connexion n'aurait pas de sens.
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

      # Habilitations chargées d'avance : le garde du second facteur les lit à chaque requête.
      @session_in_cookie = ProviderSession.includes(membership: [:agent, :process_accesses, :organization_link])
        .find_by(id: session[:provider_session_id])
    end

    # `terminate_session` plutôt que `reset_session` : ouvrir une authentification ferme
    # ce que ce navigateur détenait — anti-fixation, et une tentative abandonnée ne
    # survit pas avec son jeton.
    def adopt_session(provider_session)
      terminate_session
      session[:provider_session_id] = provider_session.id
    end

    def terminate_session
      find_session_by_cookie&.destroy
      remove_instance_variable(:@session_in_cookie)
      Current.provider_session = nil
      reset_session
    end

    # Posé une fois par requête : tout événement émis pendant celle-ci le porte, sans qu'aucun
    # point d'émission ne le connaisse. Rails le réinitialise entre deux requêtes.
    def set_event_context
      Rails.event.set_context(ip_address: request.remote_ip, user_agent: request.user_agent,
        request_id: request.request_id)
    end

    # Relu à chaque requête plutôt que porté par le cookie : un rattachement peut devenir
    # à privilèges pendant la session. On éjecte sans élever — détourner une requête
    # quelconque vers ProConnect donnerait un retour qui ne sait plus où renvoyer l'agent.
    def enforce_second_factor!
      record = find_session_by_cookie
      return unless record&.granted?
      return if Portail::Access::SecondFactor.satisfied?(record.membership,
        acr: record.acr, amr: record.amr)

      Rails.event.notify(Portail::Auth::Decision.new(
        outcome: :denied, reason: :second_factor_required,
        email: record.email, acr: record.acr, amr: record.amr,
        agent_id: record.membership.agent_id, membership_id: record.membership_id
      ))

      # `terminate_session` détruit l'enregistrement et réinitialise la session : tout se
      # lit avant, tout se réécrit après.
      email = record.email
      siret = record.membership.organization_link.siret

      terminate_session

      session[:proconnect_step_up] = true
      # Relus par SessionsController#start, pour suggérer l'adresse et l'organisation.
      session[:proconnect_step_up_email] = email
      session[:proconnect_step_up_siret] = siret
      # Vers l'élévation, pas vers un accueil qui ne dirait pas quoi faire.
      redirect_to step_up_path, alert: t("portail.sessions.second_factor_required")
    end

    def expire_stale_session!
      record = find_session_by_cookie
      # Un refus n'est pas une session ouverte : ni la borne d'inactivité ni le message
      # d'expiration ne le concernent.
      return unless record&.granted?

      Current.provider_session = record
      return close_expired_session! if record.expired?

      record.touch if record.updated_at < TOUCH_THROTTLE.ago
    end

    # Détruire plutôt qu'oublier le cookie : une session expirée ne doit pas figurer dans
    # un inventaire des sessions ouvertes.
    def close_expired_session!
      terminate_session
      redirect_to root_path, alert: t("portail.sessions.expired")
    end

    # Relu à chaque requête plutôt que porté par le cookie : retirer un rattachement ferme
    # l'accès dès la requête suivante.
    def current_membership = Current.membership

    def current_agent = Current.agent

    def agent_signed_in? = Current.agent.present?
  end
end
