# frozen_string_literal: true

module Portail
  # La configuration des abonnements de l'organisation, réservée à l'administrateur local, quelles
  # que soient ses habilitations : elles bornent les télédossiers, pas les abonnements. La requête
  # amont porte l'organisation ; ici on vérifie qu'il l'a tenue.
  class SubscriptionPolicy
    class << self
      def readable?(membership, subscription)
        membership.local_administrator? && Access::OrganizationPerimeter.covers?(membership, subscription.subscriber)
      end
    end

    attr_reader :membership, :subscription

    # Pour la liste, le record est la classe : seul le rattachement y compte.
    def initialize(membership, subscription)
      @membership = membership
      @subscription = subscription
    end

    def index? = membership.local_administrator?

    # Le détail servi : le rôle, et l'organisation que l'amont a rendue.
    def show? = SubscriptionPolicy.readable?(membership, subscription)

    class Scope
      attr_reader :membership, :scope

      def initialize(membership, scope)
        @membership = membership
        @scope = scope
      end

      def resolve = scope.select { |subscription| SubscriptionPolicy.readable?(membership, subscription) }
    end
  end
end
