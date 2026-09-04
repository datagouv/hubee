# frozen_string_literal: true

module Portail
  class SessionsController < Portail::BaseController
    # La surface d'authentification elle-même : s'y authentifier ne peut être un prérequis.
    allow_unauthenticated_access

    # Un agent dont le rattachement vient de changer doit encore pouvoir sortir, et fermer
    # sa session ProConnect avec.
    skip_before_action :enforce_second_factor!

    # Chaque appel déclenche deux requêtes sortantes vers ProConnect : sans limite, on se
    # laisse transformer en amplificateur.
    rate_limit to: 10, within: 1.minute, only: :create, with: -> { head :too_many_requests }

    # Motifs qui ne disent rien du compte de l'agent : la page d'échec générique suffit.
    TECHNICAL_FAILURES = %i[invalid_token provider_unavailable sign_in_conflict].freeze

    # Départ vers ProConnect. En POST : couvert par le jeton CSRF de Rails. Pas `authorize` :
    # ce nom est celui de la méthode de Pundit, incluse dans BaseController.
    def start
      # Les suggestions viennent d'une éjection en cours de session (cf.
      # Authentication#enforce_second_factor!) ; consommées pour ne pas survivre sur un
      # poste partagé.
      depart_for_proconnect(
        step_up: session[:proconnect_step_up].present?,
        login_hint: session.delete(:proconnect_step_up_email),
        siret_hint: session.delete(:proconnect_step_up_siret)
      )
    end

    def create
      # Les refus ProConnect arrivent en paramètre ; enchaîner l'échange du code
      # échouerait plus loin sous un motif trompeur.
      return redirect_to auth_failure_path if params[:error].present?
      return redirect_to auth_failure_path unless valid_state?

      result = Portail::Sessions::Create.call(
        code: params[:code],
        nonce: session.delete(:proconnect_nonce),
        step_up_attempted: session[:proconnect_step_up]
      )

      if result.success?
        # Lu avant : `adopt_session` réinitialise la session et l'effacerait.
        target = after_authentication_url
        adopt_session(result.provider_session)
        redirect_to target, notice: t(".signed_in")
      elsif result.error == :step_up_required
        # Retour direct vers ProConnect, sans page intermédiaire : les suggestions sortent
        # du userinfo qu'on vient de lire, rien ne transite par la session.
        session[:proconnect_step_up] = true
        depart_for_proconnect(step_up: true, login_hint: result.info.email, siret_hint: result.siret)
      elsif TECHNICAL_FAILURES.include?(result.error)
        redirect_to auth_failure_path
      else
        denial = Portail::Sessions::Deny.call(denial_attributes(result))
        # Sans adresse, la page de refus n'aurait rien à montrer — page d'échec plutôt
        # qu'une erreur serveur.
        return redirect_to auth_failure_path if denial.failure?

        adopt_session(denial.provider_session)
        redirect_to denied_path
      end
    end

    # L'agent est identifié chez ProConnect mais refusé ici, et sa session ProConnect
    # reste ouverte : sans explication ni issue, recliquer le ramènerait au même refus en
    # boucle. La déconnexion ProConnect reste son choix — elle vaudrait pour tous ses
    # services. Une seule vue pour tous les motifs, gardée par les traductions : un motif
    # renommé renvoie à l'accueil plutôt que de faire tomber la page.
    def denied
      @denial = find_session_by_cookie
      return redirect_to root_path unless @denial&.denied? &&
        I18n.exists?("portail.sessions.denied.#{@denial.denial_reason}.heading")

      render status: :forbidden
    end

    # Ne sert plus qu'à l'éjection en cours de session, qui porte un message que l'agent
    # doit lire avant de repartir.
    def step_up
      redirect_to root_path unless session[:proconnect_step_up]
    end

    # On ferme chez nous d'abord : ProConnect injoignable ne retient jamais personne.
    def destroy
      # Lu avant : `terminate_session` détruit l'enregistrement qui le porte.
      id_token = find_session_by_cookie&.provider_id_token
      terminate_session
      redirect_to Portail::ProConnect::Client.logout_url(id_token:), allow_other_host: true
    rescue Portail::ProConnect::Client::Unavailable
      redirect_to root_path, alert: t(".provider_unavailable")
    end

    def failure
      # L'échec clôt le parcours : sans ça, une élévation interrompue laisserait ce
      # navigateur exiger la MFA de toute connexion suivante, suggestions comprises.
      session.delete(:proconnect_step_up)
      session.delete(:proconnect_step_up_email)
      session.delete(:proconnect_step_up_siret)

      render :failure, status: :unauthorized
    end

    private

    # Un seul chemin vers ProConnect. `state` et `nonce` sont posés ici et relus au
    # retour : ce sont eux qui lient la réponse à notre demande.
    def depart_for_proconnect(step_up:, login_hint: nil, siret_hint: nil)
      authorization = Portail::ProConnect::Client.authorization(step_up:, login_hint:, siret_hint:)
      session[:proconnect_state] = authorization.state
      session[:proconnect_nonce] = authorization.nonce

      redirect_to authorization.url, allow_other_host: true
    rescue Portail::ProConnect::Client::Unavailable => e
      Rails.logger.error("ProConnect indisponible", e)
      redirect_to auth_failure_path
    end

    # Comparaison à temps constant, et consommation : un `state` ne vaut qu'un aller-retour.
    def valid_state?
      expected = session.delete(:proconnect_state)
      expected.present? && params[:state].present? &&
        ActiveSupport::SecurityUtils.secure_compare(expected, params[:state])
    end

    # Pure : traduit le contexte échoué de la chaîne vers ce que Deny consigne.
    def denial_attributes(result)
      {reason: result.error, claims: result.claims, id_token: result.id_token,
       email: result.info.email, siret: result.siret, idp_id: result.idp_id,
       organization_label: result.organization_label, agent_id: result.agent&.id}
    end
  end
end
