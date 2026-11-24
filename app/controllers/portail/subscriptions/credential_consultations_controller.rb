# frozen_string_literal: true

module Portail
  module Subscriptions
    # Une consultation des identifiants du client OAuth d'un abonnement API, au clic dans son détail : une
    # page à part, que le POST rend lui-même. Le détail est relu d'abord : le rôle, l'organisation servie
    # et le mode d'accès se jugent avant toute lecture du secret. Le secret ne passe que par la réponse,
    # sous `no-store`.
    class CredentialConsultationsController < Portail::BaseController
      # Un membre n'a pas à faire appeler l'amont pour une 404.
      before_action :require_local_administrator
      # Très sensible : une réauthentification faite juste avant, pour cet abonnement, consommée ici,
      # avant toute lecture amont. Sans elle, l'agent part la faire et revient sur l'abonnement.
      # Le retour ramène au bloc des identifiants, qui dit alors que l'identité est vérifiée.
      requires_reauthentication :credentials, only: :create, subject: -> { params[:abonnement_id] },
        return_to: -> { abonnement_path(params[:abonnement_id], anchor: "identifiants") }

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
        # Rendue par le POST, sans redirection vers un GET : une réponse GET se recharge et se retrouve
        # dans l'historique, sans nouvelle réauthentification. Recharger cette page renvoie le POST, dont
        # la preuve est déjà consommée.
        render :create, status: FAILURE_STATUSES.fetch(result.error, :ok),
          locals: {subscription:, credentials: result.credentials, failure: result.error}
      end
    end
  end
end
