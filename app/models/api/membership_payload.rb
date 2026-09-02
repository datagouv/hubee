# frozen_string_literal: true

module API
  # Un rattachement porté par le payload de création d'agent — un agent naît
  # avec un ou plusieurs de ces objets, jamais isolément (voir AgentPayload).
  class MembershipPayload
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :siret, :string
    attribute :insee_code, :string
    attribute :role, :string
    attribute :job_title, :string
    attribute :phone_number, :string

    validates :insee_code, presence: true
    validates :siret, presence: true, format: {with: OrganizationLink::SIRET_FORMAT, allow_blank: true}
    # Un privilège ne se déduit pas d'un défaut : le rôle est exigé, jamais présumé.
    validates :role, presence: true, inclusion: {in: Membership.roles.keys, allow_blank: true}
  end
end
