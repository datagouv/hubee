# frozen_string_literal: true

module API
  module Internal
    module V1
      class BaseController < API::BaseController
        include Pundit::Authorization

        rescue_from Pundit::NotAuthorizedError, with: :forbidden

        private

        # Le sujet des policies est le client de l'API, qui porte ses droits.
        def pundit_user = current_api_client

        def forbidden = render(json: {error: "forbidden", message: I18n.t("api.errors.forbidden")}, status: :forbidden)
      end
    end
  end
end
