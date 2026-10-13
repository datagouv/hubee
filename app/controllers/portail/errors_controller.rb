# frozen_string_literal: true

module Portail
  class ErrorsController < Portail::BaseController
    allow_unauthenticated_access

    # Seul le HTML existe : une URL inexistante en `.zip` ou `.json` ferait planter la page
    # d'erreur elle-même, et Rails renverrait une 500 brute qui échappe à Sentry.
    before_action { request.format = :html }

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
