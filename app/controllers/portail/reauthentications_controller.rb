# frozen_string_literal: true

module Portail
  # Le départ d'une réauthentification et le retour de la déconnexion ProConnect qui l'ouvre. Le
  # retour de la connexion qui la conclut est celui de toute connexion : SessionsController#create.
  class ReauthenticationsController < Portail::BaseController
    # L'agent agit sur sa propre session : il n'y a pas de ressource à autoriser.
    skip_after_action :verify_authorized

    PURPOSE_MAX_LENGTH = 200

    # Déconnecte l'agent de ProConnect, y compris de ses autres services : sa session ProConnect,
    # ou celle de son fournisseur d'identité, ne doit pas suffire à la reconnexion qui suit.
    def create
      return_to = local_path(params[:return_to])
      session[:reauthentication] = {
        "purpose" => params.require(:purpose).to_s.first(PURPOSE_MAX_LENGTH), "return_to" => return_to,
        "provider_session_id" => Current.provider_session.id, "started_at" => Time.current.to_i
      }

      redirect_to Portail::ProConnect::Client.reauthentication_logout_url(
        id_token: Current.provider_session.provider_id_token
      ), allow_other_host: true
    rescue Portail::ProConnect::Client::Unavailable
      # Rien n'a été fermé : l'agent retrouve sa page.
      session.delete(:reauthentication)
      redirect_to return_to, alert: t("portail.reauthentications.failed")
    end

    # Retour de la déconnexion : la connexion relancée par le portail, avec l'adresse et
    # l'organisation de la session suggérées. Le second facteur est demandé si le rattachement
    # l'exige, comme à la connexion.
    def resume
      return redirect_to root_path if pending_reauthentication.nil?

      depart_for_proconnect(
        step_up: Access::SecondFactor.required_for?(current_membership),
        login_hint: current_agent.email,
        siret_hint: current_membership.organization_link.siret
      )
    end

    private

    # Un chemin, jamais une URL : sinon redirection arbitraire vers un autre site.
    def local_path(candidate)
      path = candidate.to_s
      (path.start_with?("/") && !path.start_with?("//")) ? path : root_path
    end
  end
end
