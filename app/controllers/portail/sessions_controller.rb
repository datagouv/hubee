# frozen_string_literal: true

module Portail
  class SessionsController < Portail::BaseController
    # La surface d'authentification elle-même : s'y authentifier ne peut être un prérequis.
    allow_unauthenticated_access

    # Entrer et sortir doit rester possible quels que soient les droits : un agent dont le
    # rattachement vient de changer doit pouvoir se déconnecter, et fermer aussi sa session
    # ProConnect.
    skip_before_action :enforce_second_factor!

    # Ouvert à tous, et chaque appel déclenche deux requêtes sortantes vers ProConnect —
    # échange du code puis userinfo. Sans limite, on se laisse transformer en amplificateur.
    rate_limit to: 10, within: 1.minute, only: :create, with: -> { head :too_many_requests }

    # Motifs qui ne portent aucun jugement sur l'agent : rien à lui expliquer sur son
    # compte, la page d'échec générique suffit.
    TECHNICAL_FAILURES = %i[invalid_token provider_unavailable sign_in_conflict].freeze

    # Le départ vers ProConnect, déclenché par l'agent. En POST, donc couvert par le jeton
    # CSRF de Rails — la garantie qu'apportait omniauth-rails_csrf_protection, mais native :
    # ce gem n'existait que parce que le middleware s'exécutait avant les contrôleurs.
    def authorize
      # Le marqueur ne subsiste que pour l'éjection en cours de session, seul cas où l'agent
      # repasse par une page. L'élévation ordinaire repart directement du callback.
      depart_for_proconnect(step_up: session[:proconnect_step_up].present?)
    end

    def create
      # ProConnect renvoie ses refus en paramètre. Les lire avant tout : enchaîner l'échange
      # du code échouerait plus loin, sous un motif trompeur — les journaux parleraient de
      # décodage JWT là où il faudrait lire le refus lui-même.
      return redirect_to auth_failure_path if params[:error].present?
      return redirect_to auth_failure_path unless valid_state?

      tokens = Portail::ProConnect::Client.exchange(code: params[:code])
      result = Portail::Sessions::Create.call(
        id_token: tokens.id_token,
        nonce: session.delete(:proconnect_nonce),
        info: tokens.info,
        siret: tokens.siret,
        idp_id: tokens.idp_id,
        organization_label: tokens.organization_label,
        step_up_attempted: session[:proconnect_step_up]
      )

      if result.success?
        # Lu avant : `adopt_session` réinitialise la session et l'effacerait.
        target = after_authentication_url
        adopt_session(result.provider_session)
        redirect_to target, notice: t(".signed_in")
      elsif result.error == :step_up_required
        # On repart d'ici, sans page intermédiaire : c'est ce que la phase requête
        # d'OmniAuth interdisait. Les suggestions viennent du userinfo qu'on vient de lire,
        # plus de la session — rien ne traîne pour le suivant sur un poste partagé.
        session[:proconnect_step_up] = true
        depart_for_proconnect(step_up: true, login_hint: tokens.info.email, siret_hint: tokens.siret)
      elsif TECHNICAL_FAILURES.include?(result.error)
        redirect_to auth_failure_path
      else
        deny_access!(result, tokens)
      end
    rescue Portail::ProConnect::Client::Unavailable => e
      # L'échange du code ou le userinfo n'a pas abouti : rien n'est imputable à l'agent.
      Rails.logger.error("[ProConnect] #{e.message}")
      redirect_to auth_failure_path
    end

    # L'agent est authentifié chez ProConnect mais le portail lui refuse l'entrée. Sa
    # session ProConnect reste ouverte : sans action de sa part, recliquer sur le bouton
    # le réauthentifierait à l'identique, en boucle. On lui montre donc l'adresse qu'il
    # vient d'utiliser, et un moyen de repartir sur un autre compte.
    #
    # La déconnexion n'est pas déclenchée d'office : elle le sortirait de ProConnect pour
    # tous les services, pas seulement pour HubEE. C'est son choix, pas le nôtre.
    #
    # Une seule vue pour tous les motifs : seul le message change. D'où la garde par les
    # traductions — un enregistrement antérieur à un renommage de motif renvoie à l'accueil
    # plutôt que de faire tomber la page.
    def denied
      @denial = find_session_by_cookie
      return redirect_to root_path unless @denial&.denied? &&
        I18n.exists?("portail.sessions.denied.#{@denial.denial_reason}.heading")

      render status: :forbidden
    end

    # Ne subsiste que pour l'éjection en cours de session : elle porte un message que
    # l'agent doit lire avant de repartir. L'élévation à la connexion, elle, n'affiche plus
    # rien.
    def step_up
      redirect_to root_path unless session[:proconnect_step_up]
    end

    # Sert la déconnexion d'un agent entré comme l'abandon d'une tentative refusée : dans
    # les deux cas on ferme chez nous d'abord, pour que ProConnect injoignable ne retienne
    # jamais personne.
    def destroy
      # Lu avant : `terminate_session` détruit l'enregistrement qui le porte.
      id_token = find_session_by_cookie&.provider_id_token
      terminate_session
      redirect_to Portail::ProConnect::Client.logout_url(
        id_token:, post_logout_redirect_uri: ENV.fetch("PROCONNECT_POST_LOGOUT_REDIRECT_URI")
      ), allow_other_host: true
    rescue Portail::ProConnect::Client::Unavailable
      redirect_to root_path, alert: t(".provider_unavailable")
    end

    def failure
      render :failure, status: :unauthorized
    end

    private

    # Un seul chemin vers ProConnect, quel que soit l'appelant. `state` et `nonce` sont
    # posés ici et relus au retour : ce sont eux qui lient la réponse à notre demande.
    #
    # ProConnect muet, on ne peut ni commencer ni imputer quoi que ce soit à l'agent : la
    # page d'échec vaut mieux qu'une erreur serveur sur le chemin d'authentification.
    def depart_for_proconnect(step_up:, login_hint: nil, siret_hint: nil)
      authorization = Portail::ProConnect::Client.authorization(step_up:, login_hint:, siret_hint:)
      session[:proconnect_state] = authorization.state
      session[:proconnect_nonce] = authorization.nonce

      redirect_to authorization.url, allow_other_host: true
    rescue Portail::ProConnect::Client::Unavailable => e
      Rails.logger.error("[ProConnect] #{e.message}")
      redirect_to auth_failure_path
    end

    # Comparaison à temps constant, et consommation : un `state` ne vaut que pour un seul
    # aller-retour, sinon un callback intercepté pourrait être rejoué.
    def valid_state?
      expected = session.delete(:proconnect_state)
      expected.present? && params[:state].present? &&
        ActiveSupport::SecurityUtils.secure_compare(expected, params[:state])
    end

    # Sans adresse, la page de refus n'aurait rien à montrer — la page d'échec vaut mieux
    # qu'une erreur serveur sur le chemin d'authentification.
    def deny_access!(result, tokens)
      denial = Portail::Sessions::Deny.call(
        reason: result.error, claims: result.claims,
        id_token: tokens.id_token, email: tokens.info.email,
        siret: tokens.siret, idp_id: tokens.idp_id,
        organization_label: tokens.organization_label,
        agent_id: result.agent&.id
      )
      return redirect_to auth_failure_path if denial.failure?

      adopt_session(denial.provider_session)
      redirect_to denied_path
    end
  end
end
