# frozen_string_literal: true

module Portail
  class ErrorsController < Portail::BaseController
    allow_unauthenticated_access
    # Aucune ressource à autoriser sur une page d'erreur.
    skip_after_action :verify_authorized, :verify_policy_scoped

    def not_found
      render status: :not_found
    end

    def unprocessable_entity
      render status: :unprocessable_content
    end

    def internal_server_error
      render status: :internal_server_error
    end
  end
end
