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
      # Ce que le bloc des identifiants propose : la consultation, ou d'abord la réauthentification. Au
      # retour d'une réauthentification faite pour cet abonnement, la consultation part d'elle-même.
      purpose = Access::Reauthentication.purpose(:credentials, @subscription.id)
      @credentials_unlocked = Access::Reauthentication.satisfied?(Current.provider_session, level: :very_sensitive,
        purpose:)
      @credentials_auto_reveal = @credentials_unlocked && flash[:reauthenticated_for] == purpose
    end
  end
end
