# frozen_string_literal: true

module Portail
  class DashboardController < Portail::BaseController
    allow_unauthenticated_access
    # Aucune ressource à autoriser sur une page d'accueil.
    skip_after_action :verify_authorized, :verify_policy_scoped

    def index
      redirect_to demarches_path if agent_signed_in?
    end
  end
end
