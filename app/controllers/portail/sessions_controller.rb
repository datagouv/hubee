# frozen_string_literal: true

module Portail
  class SessionsController < Portail::BaseController
    # La surface d'authentification elle-même : s'y authentifier ne peut être un prérequis.
    allow_unauthenticated_access

    # Ouvert à tous, et chaque appel déclenche deux requêtes sortantes vers ProConnect —
    # échange du code puis userinfo. Sans limite, on se laisse transformer en amplificateur.
    rate_limit to: 10, within: 3.minutes, only: :create, with: -> { head :too_many_requests }

    before_action :require_pending_denial, only: :denied

    # Motifs qui ne portent aucun jugement sur l'agent : rien à lui expliquer sur son
    # compte, la page d'échec générique suffit.
    TECHNICAL_FAILURES = %i[invalid_token provider_unavailable sign_in_conflict].freeze

    def create
      result = Portail::Sessions::Create.call(
        id_token: auth_hash.credentials.id_token,
        nonce: auth_hash.extra.nonce,
        info: auth_hash.info,
        siret: auth_hash.extra.raw_info&.dig("siret")
      )

      if result.success?
        # Lue avant : `start_new_session_for` réinitialise la session et l'effacerait.
        target = after_authentication_url
        start_new_session_for(result.membership, id_token: auth_hash.credentials.id_token,
          amr: result.claims[:amr], acr: result.claims[:acr])
        redirect_to target, notice: t(".signed_in")
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
    def denied
      render status: :forbidden
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

    def require_pending_denial
      @denial = pending_denial
      redirect_to root_path unless @denial
    end

    # Ne rend qu'un refus qu'on sait expliquer : la liste des motifs valides est celle des
    # traductions, si bien qu'un enregistrement antérieur à un renommage ne fait pas
    # tomber la page — et qu'ajouter un motif ne demande rien d'autre qu'une traduction.
    def pending_denial
      denial = find_session_by_cookie
      denial if denial&.denied? && I18n.exists?("portail.sessions.denied.#{denial.denial_reason}.heading")
    end

    # Sans adresse, la page de refus n'aurait rien à montrer — la page d'échec vaut mieux
    # qu'une erreur serveur sur le chemin d'authentification.
    def deny_access!(result)
      start_denied_session(
        denial_reason: result.error.to_s, email: auth_hash.info.email,
        provider_id_token: auth_hash.credentials.id_token,
        amr: result.claims[:amr], acr: result.claims[:acr],
        organization_label: auth_hash.extra.raw_info&.dig("organization_label")
      )
      redirect_to denied_path
    rescue ActiveRecord::RecordInvalid
      redirect_to auth_failure_path
    end
  end
end
