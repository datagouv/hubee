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

    # config.exceptions_app : l'exception levée, sous le statut que Rails ou une gem lui donne. La
    # liste n'est pas la nôtre : un statut sans page propre garde le sien, avec la page de sa
    # famille. Pas `params`, comme pour l'API.
    def show
      status = request.path_parameters[:status].to_i
      render locals: {page: page_for(status)}, status:
    end

    private

    def page_for(status)
      code = Rack::Utils::SYMBOL_TO_STATUS_CODE.key(status)
      return code if I18n.exists?("portail.errors.show.#{code}")

      (status >= 500) ? :server_error : :client_error
    end

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
