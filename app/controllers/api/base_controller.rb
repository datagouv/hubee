module API
  class BaseController < ActionController::API
    include Pagy::Method

    # Généreuse à dessein : la volumétrie légitime ne l'approche jamais, elle ne borne qu'un
    # client emballé ou un jeton volé.
    RATE_LIMIT_PER_MINUTE = 300

    # Hashé : la clé part en clair dans solid_cache, un jeton brut y ruinerait hash_token_secrets.
    rate_limit to: RATE_LIMIT_PER_MINUTE, within: 1.minute,
      by: -> { Digest::SHA256.hexdigest(request.authorization.presence || request.remote_ip) },
      with: -> { render json: {error: "rate_limited"}, status: :too_many_requests }

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
