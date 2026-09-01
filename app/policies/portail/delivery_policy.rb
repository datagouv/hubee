# frozen_string_literal: true

module Portail
  # Ce qu'un rattachement a le droit de lire.
  #
  # Le sujet est le rattachement et non l'agent : le rôle et les habilitations vivent sur lui,
  # et un même agent peut être membre dans une structure et administrateur local dans une autre.
  #
  # Deux faces de la même règle, et il faut les deux. `Scope#resolve` borne la liste ; `#show?`
  # borne le détail. Sans le second, un identifiant connu ouvrirait une démarche hors
  # habilitation : l'API amont ne borne que sur l'organisation et fait confiance à l'appelant.
  class DeliveryPolicy
    # Le périmètre de lecture, sous une forme qui ne peut pas s'inverser par accident.
    #
    # Transmis tel quel à l'amont, un tableau vide vaut « aucun filtre » : le client V1 retire
    # un critère vide de la requête et sert alors TOUTES les démarches de l'organisation, soit
    # l'inverse exact de « aucun accès ». D'où des prédicats plutôt que `nil` et `[]`.
    class Perimeter
      # Aucune restriction de flux : rien à filtrer, tout le périmètre de l'organisation.
      def self.unrestricted = new(nil)

      # Aucun flux habilité. À ne jamais confondre avec `unrestricted` : ce périmètre-ci ne
      # doit produire aucun appel, et surtout pas un appel sans filtre.
      def self.none = new([])

      def self.limited_to(codes) = new(codes)

      def initialize(codes)
        @codes = codes
      end

      def unrestricted? = @codes.nil?

      def none? = @codes == []

      def covers?(code) = unrestricted? || @codes.include?(code)

      # Ce que l'amont attend : une liste, la liste vide valant « aucun filtre ». N'a donc de
      # sens que sur un périmètre qui n'est pas `none?` — l'appelant court-circuite avant.
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

      # Le second paramètre est le contrat de Pundit ; il n'a rien à borner ici, le périmètre
      # étant résolu par l'API amont et non par une relation locale.
      def initialize(membership, _scope = nil)
        @membership = membership
      end

      # Une liste d'habilitations renseignée borne tout le monde, administrateur local compris :
      # le rôle ne tranche que le sens d'une liste VIDE. Pour un administrateur local elle vaut
      # « aucune restriction », pour un membre « aucune démarche ». C'est la règle du portail V1.
      def resolve
        codes = membership.process_accesses.pluck(:process_code)
        return Perimeter.limited_to(codes) if codes.any?

        membership.local_administrator? ? Perimeter.unrestricted : Perimeter.none
      end
    end
  end
end
