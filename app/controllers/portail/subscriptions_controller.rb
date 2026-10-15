# frozen_string_literal: true

module Portail
  class SubscriptionsController < Portail::BaseController
    def index
      # Avant toute lecture : un membre n'a pas à faire appeler l'amont pour une 404.
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
  end
end
