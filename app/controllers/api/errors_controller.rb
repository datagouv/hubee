module API
  # Hors de BaseController : une URL inconnue répond sans exiger ni lire de jeton, donc sans
  # toucher la base.
  class ErrorsController < ActionController::API
    def not_found
      render json: {error: I18n.t("api.errors.not_found")}, status: :not_found
    end
  end
end
