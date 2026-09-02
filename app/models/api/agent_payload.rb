# frozen_string_literal: true

module API
  # Les exigences du POST /api/v1/agents vivent dans ::API, pas sur les modèles
  # partagés avec ::Portail, qui doit tolérer les agents hérités incomplets.
  class AgentPayload
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :email, :string
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :civility, :string
    attr_reader :memberships

    validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP, allow_blank: true}
    validates :first_name, :last_name, presence: true
    validates :civility, inclusion: {in: Agent.civilities.keys}, allow_nil: true
    validate :memberships_content

    def memberships=(memberships)
      @memberships = Array.wrap(memberships).map { |attributes| MembershipPayload.new(attributes) }
    end

    private

    # Un agent naît avec au moins un rattachement, et l'invariant un-par-SIRET
    # (porté par Membership) vaut aussi entre les entrées d'un même appel.
    def memberships_content
      return errors.add(:memberships, :blank) if memberships.blank?

      memberships.each_with_index do |membership, index|
        next if membership.valid?

        membership.errors.each do |error|
          errors.add(:"memberships[#{index}].#{error.attribute}", error.type)
        end
      end

      sirets = memberships.filter_map { |membership| membership.siret.presence }
      errors.add(:memberships, :duplicated_siret) if sirets.uniq.length != sirets.length
    end
  end
end
