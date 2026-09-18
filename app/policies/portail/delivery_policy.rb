# frozen_string_literal: true

module Portail
  # Ce que le rattachement a le droit de lire, appliqué à ce que l'amont a servi : la requête
  # amont est déjà bornée, ici on vérifie qu'il a tenu ce contrat, sur le flux et l'organisation.
  # L'état s'y ajoute : un télédossier que le portail ne sert pas est hors périmètre pour tous.
  class DeliveryPolicy
    class << self
      # La règle, écrite une fois : pour un détail par `show?`, pour chaque ligne d'une page par
      # le scope.
      def readable?(membership, delivery)
        Access::OrganizationPerimeter.covers?(membership, delivery.recipient) &&
          Access::DataStreamPerimeter.covers?(membership, delivery.data_stream.code) &&
          Access::StatePerimeter.covers?(delivery.state)
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
