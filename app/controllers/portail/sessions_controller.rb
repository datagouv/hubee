# frozen_string_literal: true

module Portail
  class SessionsController < Portail::BaseController
    # La surface d'authentification elle-même : s'y authentifier ne peut être un prérequis.
    allow_unauthenticated_access

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

      log_proconnect_exchange(result)

      if result.success?
        target = after_authentication_url
        start_agent_session!(result.membership, auth_hash.credentials.id_token)
        redirect_to target, notice: t(".signed_in")
      elsif TECHNICAL_FAILURES.include?(result.error)
        redirect_to auth_failure_path
      else
        deny_access!(result.error)
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
      # La liste des motifs valides, c'est celle des traductions : un cookie d'avant un
      # renommage ne fait pas tomber la page, et rien n'est à tenir à jour ici.
      return redirect_to root_path unless known_denial_reason?

      @denial_reason = session[:denial_reason]
      @authenticated_email = session[:denial_email]
      # ProConnect muet, on montre quand même le motif du refus : seul le bouton de
      # changement de compte disparaît, faute de pouvoir construire son URL.
      @switch_account_url = begin
        Portail::ProConnect::LogoutUrlBuilder.call(id_token: session[:denial_id_token])
      rescue Portail::ProConnect::Discovery::Unavailable
        nil
      end
      render :denied, status: :forbidden
    end

    # reset_session d'abord : la déconnexion du portail est acquise avant tout appel
    # sortant. ProConnect injoignable ne doit jamais retenir un agent connecté.
    def destroy
      id_token = session[:proconnect_id_token]
      reset_session
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

    def known_denial_reason?
      session[:denial_reason].present? &&
        I18n.exists?("portail.sessions.denied.#{session[:denial_reason]}.heading")
    end

    # Le motif transite par la session, pas par le flash : le flash se consomme à la
    # première lecture, donc recharger la page de refus la viderait. reset_session d'abord,
    # comme à l'ouverture d'une session — on s'apprête à y déposer une identité.
    def deny_access!(reason)
      reset_session
      session[:denial_reason] = reason.to_s
      session[:denial_email] = auth_hash.info.email
      session[:denial_id_token] = auth_hash.credentials.id_token
      redirect_to denied_path
    end

    # Donne à voir ce que ProConnect a renvoyé et la décision qu'on en tire. Hors production
    # seulement : ce sont des données personnelles, et la piste d'audit relève d'un autre
    # dispositif. Le jeton lui-même n'est jamais journalisé, seuls ses claims vérifiés.
    def log_proconnect_exchange(result)
      return unless Rails.env.local?

      Rails.logger.info <<~LOG
        [ProConnect] userinfo  : #{JSON.pretty_generate(auth_hash.extra.raw_info&.to_h || {})}
        [ProConnect] id_token  : #{(result.claims || {}).inspect}
        [ProConnect] siret reçu: #{auth_hash.extra.raw_info&.dig("siret").inspect}
        [ProConnect] décision  : #{result.success? ? "entrée accordée (rattachement ##{result.membership.id})" : "refus (#{result.error})"}
      LOG
    end

    # reset_session AVANT de poser l'identité : protection contre la session fixation.
    def start_agent_session!(membership, id_token)
      reset_session
      session[:membership_id] = membership.id
      session[:proconnect_id_token] = id_token
      session[:started_at] = Time.current.to_i
      session[:last_seen_at] = Time.current.to_i
    end
  end
end
