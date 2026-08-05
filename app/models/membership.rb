# frozen_string_literal: true

# Rattachement d'un agent à une organisation. Accordé délibérément par un producteur
# externe ; le portail ne le crée jamais.
class Membership < ApplicationRecord
  # === Associations ===
  belongs_to :agent
  belongs_to :organization_link

  # === Enums ===
  # `validate: true` fait d'une valeur inconnue une erreur de validation là où Rails
  # lèverait une ArgumentError dès l'affectation.
  enum :role, {member: "member", local_administrator: "local_administrator"}, validate: true

  # === Normalisations ===
  normalizes :phone_number, with: ->(value) { PhoneNumber.normalize(value) }

  # === Validations ===
  validates :agent_id, uniqueness: {scope: :organization_link_id}

  # Ce que la normalisation n'a pas su mettre en forme est rejeté, pas effacé : l'import
  # reçoit une erreur et peut réessayer sans le numéro plutôt que de perdre l'agent.
  validates :phone_number, format: {with: PhoneNumber::E164_FORMAT}, allow_nil: true
  validates :job_title, length: {maximum: 255}
end
