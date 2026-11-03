module API
  # Hors de BaseController : une URL inconnue répond sans exiger ni lire de jeton, donc sans
  # toucher la base.
  class ErrorsController < ActionController::API
    def not_found
      render json: {error: "not_found", message: I18n.t("api.errors.not_found")}, status: :not_found
    end

    # config.exceptions_app : une exception levée sous /api, sous le statut que Rails lui donne. Pas
    # `params`, qui relirait un corps illisible.
    def show
      status = request.path_parameters[:status].to_i
      code = Rack::Utils::SYMBOL_TO_STATUS_CODE.key(status)
      render json: {error: code, message: I18n.t(code, scope: "api.errors", default: :internal_server_error)}, status:
    end

    private

    # Aucune action ne lit la query. Illisible, Rails la relirait pour son journal et la réponse
    # d'erreur échouerait à son tour ; un corps illisible, lui, y est déjà ignoré.
    def process_action(...)
      request.set_header("action_dispatch.request.query_parameters", {})
      super
    end
  end
end
