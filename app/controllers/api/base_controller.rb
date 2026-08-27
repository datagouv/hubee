module API
  class BaseController < ActionController::API
    include Pagy::Method

    before_action :doorkeeper_authorize!

    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    # Set pagination headers in response using Pagy headers extra
    # Using 'if:' instead of 'only:' to avoid Rails 7.1+ strict callback validation
    after_action :set_pagination_headers, if: -> { action_name == "index" }

    before_action :set_default_format

    private

    # Attribution : le nom du client dans le log de complétion de la requête.
    def append_info_to_payload(payload)
      super
      payload[:api_client] = current_api_client&.name
    end

    def current_api_client
      @current_api_client ||= doorkeeper_token&.application
    end

    # 401 uniforme : ne distingue pas absent, invalide, expiré, révoqué.
    def doorkeeper_unauthorized_render_options(error: nil)
      {json: {error: "invalid_token"}}
    end

    def set_default_format
      request.format = :json
    end

    def not_found
      render json: {error: "Not found"}, status: :not_found
    end

    def set_pagination_headers
      response.headers.merge!(@pagy.headers_hash) if @pagy
    end
  end
end
