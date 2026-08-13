# frozen_string_literal: true

module Portail
  class DashboardController < Portail::BaseController
    allow_unauthenticated_access

    def index
      # L'agent connecté n'a rien à faire sur une page d'accueil de visiteur.
      redirect_to demarches_path if agent_signed_in?
    end
  end
end
