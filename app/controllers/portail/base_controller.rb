# frozen_string_literal: true

module Portail
  class BaseController < ApplicationController
    include Portail::Authentication
    include Pundit::Authorization

    layout "portail"

    # Les pages du portail portent un jeton CSRF lié à la session, et cette session est
    # renouvelée à chaque connexion, refus ou déconnexion. Ressorties du cache par le
    # bouton « précédent », elles présenteraient un jeton périmé — le formulaire
    # ProConnect échouerait en InvalidAuthenticityToken. `no-store` force le navigateur à
    # redemander la page au lieu de la restituer.
    before_action :do_not_cache

    # Un onglet resté ouvert pendant qu'un autre renouvelle la session présente ensuite un
    # jeton périmé — le cas typique étant deux onglets qu'on déconnecte l'un après l'autre.
    # Aucun en-tête n'y peut rien : la page est déjà affichée. La requête reste rejetée,
    # on ne relâche pas la protection ; on remplace seulement l'erreur brute par un
    # rechargement.
    rescue_from ActionController::InvalidAuthenticityToken, with: :reload_stale_page

    # Fermé par défaut : une action qui n'a ni autorisé ni borné explose. Un contrôleur sans
    # policy s'en exempte par `skip_after_action`, comme il le fait pour l'authentification.
    after_action :verify_authorized, except: :index
    after_action :verify_policy_scoped, only: :index

    # Un refus rend la même 404 qu'une ressource inexistante : distinguer les deux révélerait
    # l'existence de ce que l'agent n'a pas à voir. Seul le journal les sépare.
    rescue_from Pundit::NotAuthorizedError, with: :refuse_access

    private

    # Une décision d'accès, pour le CSIRT : même canal que l'authentification, qui y joint le
    # contexte de requête.
    def refuse_access
      Rails.event.notify(Access::Decision.new(outcome: :refused, path: request.path,
        agent_id: current_agent.id, membership_id: current_membership.id))
      not_found
    end

    def not_found = render("portail/errors/not_found", status: :not_found)

    # Un service tiers manque : l'agent revient d'où il vient, avec l'alerte.
    def unavailable = redirect_back_or_to(root_path, alert: t("portail.errors.unavailable"))

    # Le sujet des policies est le rattachement, pas l'agent : le rôle et les habilitations
    # vivent sur lui, et un même agent peut être membre ici et administrateur local ailleurs.
    def pundit_user = current_membership

    def do_not_cache
      response.headers["Cache-Control"] = "no-store"
    end

    def reload_stale_page
      redirect_to root_path, alert: t("portail.errors.stale_page")
    end
  end
end
