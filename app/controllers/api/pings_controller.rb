module API
  # Smoke test authentifié : permet à un client de vérifier ses credentials.
  class PingsController < BaseController
    def show
      render json: {status: "ok"}
    end
  end
end
