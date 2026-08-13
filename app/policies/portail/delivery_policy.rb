# frozen_string_literal: true

module Portail
  # Ce qu'un rattachement a le droit de lire.
  #
  # Le sujet est le rattachement, pas l'agent : le rôle et les habilitations vivent sur lui,
  # et un même agent peut être membre dans une structure et administrateur local dans une
  # autre. C'est ce que `pundit_user` renvoie.
  #
  # Deux faces de la même règle, et il faut les deux. `Scope#resolve` borne la liste ;
  # `#show?` borne le détail. Sans le second, un identifiant connu ouvrirait une démarche
  # hors habilitation : l'API amont ne borne que sur l'organisation et fait confiance à
  # l'appelant pour le reste — la liste ne la montrerait pas, l'URL directe si.
  class DeliveryPolicy
    attr_reader :membership, :delivery

    def initialize(membership, delivery)
      @membership = membership
      @delivery = delivery
    end

    def show?
      codes = Scope.new(membership, nil).resolve
      return true if codes.nil?

      codes.include?(delivery.data_stream.code)
    end

    class Scope
      attr_reader :membership

      # Le second paramètre est le contrat de Pundit ; il n'a rien à borner ici, le
      # périmètre étant résolu par l'API amont et non par une relation locale.
      def initialize(membership, _scope = nil)
        @membership = membership
      end

      # Trois retours, et la distinction entre les deux derniers est l'enjeu de cette
      # classe : nil vaut « aucun filtre », un tableau de codes borne, et un tableau vide
      # signifie « aucun accès ». Transmis tel quel à l'API, ce tableau vide vaudrait
      # « aucun filtre », soit l'inverse exact — c'est à l'appelant de le distinguer.
      def resolve
        # L'administrateur local administre l'organisation entière : le filtrer le
        # priverait de sa fonction.
        return nil if membership.local_administrator?

        membership.process_accesses.pluck(:process_code)
      end
    end
  end
end
