# frozen_string_literal: true

module Portail
  module Subscriptions
    # Une consultation des identifiants du client OAuth d'un abonnement API, au clic dans son détail. Le
    # détail est relu d'abord : le rôle, l'organisation servie et le mode d'accès se jugent avant
    # toute lecture du secret. Le secret ne passe que par la réponse, sous `no-store`.
    class CredentialConsultationsController < Portail::BaseController
      # Un membre n'a pas à faire appeler l'amont pour une 404.
      before_action :require_local_administrator
      # Le bouton passe par Turbo : une autre requête ne crée pas de consultation.
      before_action :require_turbo_stream

      FAILURE_STATUSES = {refused: :conflict, unavailable: :service_unavailable}.freeze

      def create
        found = Subscriptions::Show.call(membership: current_membership, id: params[:abonnement_id])

        unless found.success?
          # Rien à autoriser : aucun abonnement n'a été trouvé.
          skip_authorization
          return (found.error == :not_found) ? not_found : unavailable
        end

        subscription = authorize(found.detail.subscription, :consult_credentials?)
        result = CredentialConsultations::Create.call(membership: current_membership, subscription:, request_id: request.request_id)
        render :create, status: FAILURE_STATUSES.fetch(result.error, :ok),
          locals: {credentials: result.credentials, failure: result.error}
      end

      private

      def require_turbo_stream
        head :not_acceptable unless request.format.turbo_stream?
      end
    end
  end
end
