module Api
  class BaseController < ActionController::API
    include Pagy::Backend

    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    # Set pagination headers in response using Pagy headers extra
    after_action :set_pagination_headers, only: :index

    before_action :set_default_format

    private

    def set_default_format
      request.format = :json
    end

    def not_found
      render json: {error: "Not found"}, status: :not_found
    end

    def set_pagination_headers
      pagy_headers_merge(@pagy) if @pagy
    end
  end
end
