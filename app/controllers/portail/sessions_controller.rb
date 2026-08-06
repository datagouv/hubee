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

    def create
      result = Portail::Sessions::Create.call(
        id_token: auth_hash.credentials.id_token,
        nonce: auth_hash.extra.nonce,
        info: auth_hash.info,
        siret: auth_hash.extra.raw_info&.dig("siret"),
        idp_id: auth_hash.extra.raw_info&.dig("idp_id"),
        organization_label: auth_hash.extra.raw_info&.dig("organization_label"),
        step_up_attempted: session[:proconnect_step_up]
      )

      if result.success?
        # Lus avant : `adopt_session` réinitialise la session et les effacerait.
        target = after_authentication_url
        remember_device = session[:proconnect_remember_device]
        adopt_session(result.provider_session)
        remember_device!(remember_device, result.membership)
        redirect_to target, notice: t(".signed_in")
      elsif result.error == :step_up_required
        session[:proconnect_step_up] = true
        # L'agent vient de les fournir : ProConnect n'a pas à les redemander à vide.
        session[:proconnect_step_up_email] = auth_hash.info.email
        session[:proconnect_step_up_siret] = auth_hash.extra.raw_info&.dig("siret")
        redirect_to step_up_path
      elsif TECHNICAL_FAILURES.include?(result.error)
        redirect_to auth_failure_path
      else
        deny_access!(result)
      end
    end

    # L'agent est authentifié chez ProConnect mais le portail lui refuse l'entrée. Sa
    # session ProConnect reste ouverte : sans action de sa part, recliquer sur le bouton
    # le réauthentifierait à l'identique, en boucle. On lui montre donc l'adresse qu'il
    # vient d'utiliser, et un moyen de repartir sur un autre compte.
    #
    # La déconnexion n'est pas déclenchée d'office : elle le sortirait de ProConnect pour
    # tous les services, pas seulement pour HubEE. C'est son choix, pas le nôtre.
    #
    # Une seule vue pour tous les motifs : seul le message change. Tout nouveau refus
    # atterrit ici sans code supplémentaire — il lui suffit de ses deux clés de traduction.
    # D'où la garde par les traductions : un enregistrement antérieur à un renommage de
    # motif renvoie à l'accueil plutôt que de faire tomber la page.
    def denied
      @denial = find_session_by_cookie
      return redirect_to root_path unless @denial&.denied? &&
        I18n.exists?("portail.sessions.denied.#{@denial.denial_reason}.heading")

      render status: :forbidden
    end

    # Le marqueur porte à la fois la page et sa raison d'être : sans lui, l'adresse est
    # arrivée par un lien ou un signet, et il n'y a rien à élever.
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
      redirect_to Portail::ProConnect::LogoutUrlBuilder.call(id_token:), allow_other_host: true
    rescue Portail::ProConnect::Discovery::Unavailable
      redirect_to root_path, alert: t(".provider_unavailable")
    end

    def failure
      render :failure, status: :unauthorized
    end

    private

    def auth_hash
      request.env["omniauth.auth"]
    end

    # Mémorise que ce navigateur sert à un compte à privilèges, pour lui exiger la MFA dès
    # la première autorisation et lui épargner l'aller-retour d'élévation. Aucune identité
    # dedans, et il ne peut qu'élever l'exigence — d'où l'absence de signature.
    # `nil` signifie que la question n'a pas été posée : on laisse alors le choix précédent.
    def remember_device!(choice, membership)
      # Un agent qui n'y est plus soumis efface le marquage : sans ça, un rattachement
      # rétrogradé laisserait le navigateur réclamer la MFA pour toujours, et l'agent ne
      # reverrait jamais la case pour la décocher.
      return cookies.delete(OmniAuth::Strategies::ProconnectHardened::PRIVILEGED_DEVICE_COOKIE) unless
        Portail::SecondFactor.required_for?(membership)
      return if choice.nil?

      if choice
        cookies[OmniAuth::Strategies::ProconnectHardened::PRIVILEGED_DEVICE_COOKIE] = {
          value: "1", expires: 1.year, httponly: true, same_site: :lax, secure: request.ssl?
        }
      else
        cookies.delete(OmniAuth::Strategies::ProconnectHardened::PRIVILEGED_DEVICE_COOKIE)
      end
    end

    # Sans adresse, la page de refus n'aurait rien à montrer — la page d'échec vaut mieux
    # qu'une erreur serveur sur le chemin d'authentification.
    def deny_access!(result)
      denial = Portail::Sessions::Deny.call(
        reason: result.error, claims: result.claims,
        id_token: auth_hash.credentials.id_token, email: auth_hash.info.email,
        siret: auth_hash.extra.raw_info&.dig("siret"),
        idp_id: auth_hash.extra.raw_info&.dig("idp_id"),
        organization_label: auth_hash.extra.raw_info&.dig("organization_label"),
        agent_id: result.agent&.id
      )
      return redirect_to auth_failure_path if denial.failure?

      adopt_session(denial.provider_session)
      redirect_to denied_path
    end
  end
end
