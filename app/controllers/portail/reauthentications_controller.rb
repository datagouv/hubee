# frozen_string_literal: true

module Portail
  # Le retour de la déconnexion ProConnect qui ouvre une réauthentification. Le départ est le garde de
  # l'action sensible (cf. Portail::Reauthentication) ; le retour de la connexion qui la conclut est
  # celui de toute connexion : SessionsController#create.
  class ReauthenticationsController < Portail::BaseController
    # L'agent agit sur sa propre session : il n'y a pas de ressource à autoriser.
    skip_after_action :verify_authorized

    # La connexion relancée par le portail, avec l'adresse et l'organisation de la session suggérées.
    # Le second facteur est demandé si le rattachement l'exige, comme à la connexion.
    def start
      pending = pending_reauthentication
      return redirect_to root_path if pending.nil?

      state = depart_for_proconnect(
        step_up: Access::SecondFactor.required_for?(current_membership),
        login_hint: current_agent.email,
        siret_hint: current_membership.organization_link.siret,
        # ProConnect injoignable : l'agent, toujours connecté, retrouve sa page.
        unavailable_path: pending["return_to"], unavailable_alert: t("portail.reauthentications.failed")
      )
      # Le `state` de cette connexion, et d'aucune autre : une connexion ordinaire lancée pendant
      # l'attente ne conclut pas la réauthentification. Sans départ, le parcours est abandonné.
      if state
        session[:reauthentication] = pending.merge("state" => state)
      else
        session.delete(:reauthentication)
      end
    end
  end
end
