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

    private

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
