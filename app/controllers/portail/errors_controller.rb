# frozen_string_literal: true

module Portail
  class ErrorsController < Portail::BaseController
    allow_unauthenticated_access

    # Seul le HTML existe : une URL inexistante en `.zip` ou `.json` ferait planter la page
    # d'erreur elle-même, et Rails renverrait une 500 brute qui échappe à Sentry.
    before_action { request.format = :html }

    # La page d'erreur ne lit pas la base : elle doit s'afficher même quand c'est la base qui a
    # causé l'erreur. L'agent n'est dans l'en-tête que si l'action en erreur l'avait déjà lu.
    skip_before_action :resume_session

    def bad_request
      render status: :bad_request
    end

    def not_found
      render status: :not_found
    end

    def not_acceptable
      render status: :not_acceptable
    end

    def unprocessable_entity
      render status: :unprocessable_content
    end

    def internal_server_error
      render status: :internal_server_error
    end

    private

    # Aucune action ne lit les paramètres. Illisibles, la query ou le corps de la requête fautive
    # feraient échouer la page d'erreur à son tour : Rails répondrait par sa 500 de secours en
    # texte brut.
    def process_action(...)
      request.set_header("action_dispatch.request.query_parameters", {})
      request.set_header("action_dispatch.request.request_parameters", {})
      super
    end
  end
end
