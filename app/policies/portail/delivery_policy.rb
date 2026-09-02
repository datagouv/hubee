# frozen_string_literal: true

module Portail
  # Ce que le rattachement a le droit de lire, appliqué à ce que l'amont a servi : la requête
  # amont est déjà bornée, ici on vérifie qu'il a tenu ce contrat, sur le flux et l'organisation.
  class DeliveryPolicy
    class << self
      # La règle, écrite une fois : pour un détail par `show?`, pour chaque ligne d'une page par
      # le scope.
      def readable?(membership, delivery)
        delivery.recipient.matches?(membership.organization_link) &&
          ReadingPerimeter.covers?(membership, delivery.data_stream.code)
      end
    end

    attr_reader :membership, :delivery

    def initialize(membership, delivery)
      @membership = membership
      @delivery = delivery
    end

    def show? = DeliveryPolicy.readable?(membership, delivery)

    class Scope
      attr_reader :membership, :scope

      def initialize(membership, scope)
        @membership = membership
        @scope = scope
      end

      def resolve = scope.select { |delivery| DeliveryPolicy.readable?(membership, delivery) }
    end
  end
end
