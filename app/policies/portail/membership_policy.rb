# frozen_string_literal: true

module Portail
  # Les agents de l'organisation, réservés à l'administrateur local, quelles que soient ses
  # habilitations : elles bornent les télédossiers, pas cette liste. Les rattachements sont en
  # base : le scope n'y vérifie pas un amont, il est la borne elle-même.
  class MembershipPolicy
    attr_reader :membership

    # La liste n'a pas d'enregistrement à juger : seul le rattachement compte.
    def initialize(membership, _record)
      @membership = membership
    end

    def index? = membership.local_administrator?

    class Scope
      attr_reader :membership, :scope

      def initialize(membership, scope)
        @membership = membership
        @scope = scope
      end

      # Le lien et non le SIRET : deux organisations peuvent le partager.
      def resolve
        return scope.none unless membership.local_administrator?

        scope.where(organization_link_id: membership.organization_link_id)
      end
    end
  end
end
