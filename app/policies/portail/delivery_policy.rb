# frozen_string_literal: true

module Portail
  # Ce qu'un rattachement a le droit de lire. Le sujet est le rattachement et non l'agent :
  # le rôle et les habilitations vivent sur lui.
  #
  # `Scope#resolve` borne la liste, `#show?` borne le détail. Sans le second, un identifiant
  # connu ouvrirait une démarche hors habilitation : l'amont ne borne que sur l'organisation.
  class DeliveryPolicy
    # Transmis tel quel à l'amont, un tableau vide vaut « aucun filtre », soit l'inverse exact
    # de « aucun accès ». D'où des prédicats plutôt que `nil` et `[]`.
    class Perimeter
      def self.unrestricted = new(nil)

      # Ne doit produire aucun appel, et surtout pas un appel sans filtre.
      def self.none = new([])

      def self.limited_to(codes) = new(codes)

      def initialize(codes)
        @codes = codes
      end

      def unrestricted? = @codes.nil?

      def none? = @codes == []

      def covers?(code) = unrestricted? || @codes.include?(code)

      # Ce que l'amont attend. N'a de sens que hors `none?` : l'appelant court-circuite avant.
      def filter = @codes || []
    end

    attr_reader :membership, :delivery

    def initialize(membership, delivery)
      @membership = membership
      @delivery = delivery
    end

    def show? = Scope.new(membership).resolve.covers?(delivery.data_stream.code)

    class Scope
      attr_reader :membership

      # Le second paramètre est le contrat de Pundit : rien à borner localement, le périmètre
      # est résolu par l'API amont.
      def initialize(membership, _scope = nil)
        @membership = membership
      end

      # Des habilitations renseignées bornent tout le monde, administrateur local compris. Le
      # rôle ne tranche que la liste vide : tout pour l'administrateur, rien pour le membre.
      def resolve
        codes = membership.process_accesses.pluck(:process_code)
        return Perimeter.limited_to(codes) if codes.any?

        membership.local_administrator? ? Perimeter.unrestricted : Perimeter.none
      end
    end
  end
end
