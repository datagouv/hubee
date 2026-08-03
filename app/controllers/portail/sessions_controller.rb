# frozen_string_literal: true

module Portail
  class SessionsController < Portail::BaseController
    def create
      result = Portail::Sessions::Create.call(
        id_token: auth_hash.credentials.id_token,
        nonce: auth_hash.extra.nonce,
        info: auth_hash.info
      )

      if result.success?
        start_agent_session!(result.agent, auth_hash.credentials.id_token)
        redirect_to root_path, notice: t(".signed_in")
      elsif result.error == :unknown_agent
        render_unknown_agent
      else
        redirect_to auth_failure_path
      end
    end

    def destroy
      id_token = session[:proconnect_id_token]
      reset_session
      redirect_to Portail::ProConnect::LogoutUrlBuilder.call(id_token:), allow_other_host: true
    end

    def failure
      render :failure, status: :unauthorized
    end

    private

    def auth_hash
      request.env["omniauth.auth"]
    end

    # L'agent est authentifié chez ProConnect mais inconnu du portail. Sa session
    # ProConnect reste ouverte : sans action de sa part, recliquer sur le bouton le
    # réauthentifierait à l'identique, en boucle. On lui montre donc l'adresse qu'il
    # vient d'utiliser, et un moyen de repartir sur un autre compte.
    #
    # La déconnexion n'est pas déclenchée d'office : elle le sortirait de ProConnect
    # pour tous les services, pas seulement pour HubEE. C'est son choix, pas le nôtre.
    def render_unknown_agent
      @authenticated_email = auth_hash.info.email
      @switch_account_url = Portail::ProConnect::LogoutUrlBuilder.call(
        id_token: auth_hash.credentials.id_token
      )
      render :unknown, status: :forbidden
    end

    # reset_session AVANT de poser l'identité : protection contre la session fixation.
    def start_agent_session!(agent, id_token)
      reset_session
      session[:agent_id] = agent.id
      session[:proconnect_id_token] = id_token
    end
  end
end
