# frozen_string_literal: true

module Portail
  class SubscriptionsController < Portail::BaseController
    # Un membre n'a pas à faire appeler l'amont pour une 404.
    before_action :require_local_administrator

    def index
      authorize Subscription

      result = Subscriptions::Index.call(membership: current_membership)

      unless result.success?
        # Rien à borner : aucune liste n'a été lue.
        skip_policy_scope
        @failure = result.error
        return
      end

      # La requête était bornée sur l'organisation ; le scope vérifie que l'amont l'a tenue.
      @subscriptions = policy_scope(result.subscriptions.by_data_stream_name,
        policy_scope_class: SubscriptionPolicy::Scope)
    end

    def show
      result = Subscriptions::Show.call(membership: current_membership, id: params[:id])

      unless result.success?
        # Rien à autoriser : aucun abonnement n'a été trouvé.
        skip_authorization
        return (result.error == :not_found) ? not_found : unavailable
      end

      # Le rôle et l'organisation servie, jugés ensemble comme pour un télédossier : l'amont n'est
      # pas cru sur parole.
      authorize(result.detail.subscription)
      # Par leur nom et non par `deconstruct`, qui lierait ce contrôleur à l'ordre des membres.
      @subscription = result.detail.subscription
      @emails = result.detail.delivery_email_configuration
      @delegation = result.detail.delegation
      @credentials_access = credentials_access(@subscription)
    end

    private

    # Ce que propose le bloc des identifiants. Il n'ouvre rien : la consultation reste gardée par la
    # preuve, consommée côté serveur.
    # - :reauthentication_required : le bouton part d'abord vers la réauthentification ;
    # - :available : une preuve vaut encore, le bouton consulte ;
    # - :reveal_now : retour de la réauthentification faite pour cet abonnement, la consultation part
    #   d'elle-même.
    def credentials_access(subscription)
      purpose = Access::Reauthentication.purpose(:credentials, subscription.id)
      return :reauthentication_required unless
        Access::Reauthentication.satisfied?(Current.provider_session, level: :very_sensitive, purpose:)

      (flash[:reauthenticated_for] == purpose) ? :reveal_now : :available
    end
  end
end
