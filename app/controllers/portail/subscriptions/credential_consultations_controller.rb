# frozen_string_literal: true

module Portail
  module Subscriptions
    # Une consultation des identifiants du client OAuth d'un abonnement API, au clic dans son détail. Le
    # détail est relu d'abord : le rôle, l'organisation servie et le mode d'accès se jugent avant
    # toute lecture du secret. Le secret ne passe que par la réponse, sous `no-store`.
    class CredentialConsultationsController < Portail::BaseController
      # Un membre n'a pas à faire appeler l'amont pour une 404.
      before_action :require_local_administrator
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
        return not_found if result.error == :not_found
        render :create, status: FAILURE_STATUSES.fetch(result.error, :ok),
          locals: {credentials: result.credentials, failure: result.error}
      end

      private

      # Sans JavaScript, le bouton poste un formulaire ordinaire : une page qui dit pourquoi rien ne
      # s'affiche, avant toute lecture et toute trace.
      def require_turbo_stream
        return if request.format.turbo_stream?

        render :javascript_required, status: :not_acceptable, formats: [:html],
          locals: {subscription_id: params[:abonnement_id]}
      end
    end
  end
end
