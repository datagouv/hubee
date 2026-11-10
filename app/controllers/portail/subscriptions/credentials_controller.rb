# frozen_string_literal: true

module Portail
  module Subscriptions
    # Les identifiants du client OAuth d'un abonnement API, montrés dans son détail : en Turbo Stream
    # au clic, en page entière sans JavaScript. Le détail est relu d'abord : le rôle, l'organisation
    # servie et le mode d'accès se jugent avant toute lecture du secret.
    class CredentialsController < Portail::BaseController
      # Un membre n'a pas à faire appeler l'amont pour une 404.
      before_action :require_local_administrator

      def create
        found = Subscriptions::Show.call(membership: current_membership, id: params[:id])

        unless found.success?
          # Rien à autoriser : aucun abonnement n'a été trouvé.
          skip_authorization
          return (found.error == :not_found) ? not_found : unavailable
        end

        @subscription = found.detail.subscription
        authorize(@subscription, :reveal_credentials?)

        result = Credentials::Create.call(membership: current_membership, subscription: @subscription)
        return render_section(found.detail, status: :ok, credentials: result.credentials) if result.success?

        case result.error
        when :refused then render_section(found.detail, status: :unprocessable_content, refusal: result.reason)
        when :not_found then not_found
        else unavailable
        end
      end

      private

      def render_section(detail, status:, credentials: nil, refusal: nil)
        @credentials = credentials
        @refusal = refusal

        respond_to do |format|
          format.turbo_stream { render :create, status: status }
          format.html do
            # Les mêmes variables que SubscriptionsController#show, dont la vue est rendue ici : une
            # variable ajoutée à cette vue doit l'être aussi ici.
            @emails = detail.delivery_email_configuration
            @delegation = detail.delegation
            render "portail/subscriptions/show", status: status
          end
        end
      end
    end
  end
end
