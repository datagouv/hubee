# frozen_string_literal: true

module Portail
  # `Scope#resolve` borne la liste, `#show?` le détail. Sans le second, un identifiant connu
  # ouvrirait une démarche hors habilitation : l'amont ne borne que sur l'organisation.
  class DeliveryPolicy
    attr_reader :membership, :delivery

    def initialize(membership, delivery)
      @membership = membership
      @delivery = delivery
    end

    def show? = ReadingPerimeter.for(membership).covers?(delivery.data_stream.code)

    class Scope
      attr_reader :membership

      # Le second paramètre est le contrat de Pundit. La source étant distante, `resolve` rend
      # une description du périmètre et non une relation.
      def initialize(membership, _scope = nil)
        @membership = membership
      end

      def resolve = ReadingPerimeter.for(membership)
    end
  end
end
