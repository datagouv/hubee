# frozen_string_literal: true

module API
  module Internal
    module V1
      class BaseController < API::BaseController
        include Pundit::Authorization

        rescue_from Pundit::NotAuthorizedError, with: :forbidden

        # Fermé par défaut, comme le portail : une action ajoutée qui oublierait d'autoriser explose au
        # lieu de servir tout client authentifié. Un rendu qui arrête la chaîne avant l'action (401 de
        # Doorkeeper) ou une exception rattrapée (403, 404, 400) n'atteint pas ce contrôle.
        after_action :verify_authorized

        private

        # Le sujet des policies est le client de l'API, qui porte ses droits.
        def pundit_user = current_api_client

        def forbidden = render(json: {error: "forbidden", message: I18n.t("api.errors.forbidden")}, status: :forbidden)
      end
    end
  end
end
