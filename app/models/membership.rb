# frozen_string_literal: true

# Rattachement d'un agent à une organisation. Accordé délibérément par un producteur
# externe ; le portail ne le crée jamais.
class Membership < ApplicationRecord
  # === Associations ===
  belongs_to :agent
  belongs_to :organization_link
  # Pas de `dependent:` — la cascade est portée par la base.
  has_many :process_accesses

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

  # L'invariant traverse une jointure, aucun index ne peut le tenir : validation seule,
  # fenêtre de course assumée tant que l'écriture des rattachements est séquentielle.
  validate :one_membership_per_siret

  # === Méthodes d'instance ===
  # Les codes des flux habilités. `map` et non `pluck` : lit l'association si elle est
  # préchargée, ce que fait l'authentification du portail à chaque requête.
  def process_codes = process_accesses.map(&:process_code)

  private

  # ProConnect n'atteste que le SIRET : deux rattachements le partageant seraient
  # indépartageables à la connexion.
  def one_membership_per_siret
    return if agent_id.blank? || organization_link.nil?

    clash = self.class.joins(:organization_link)
      .where(agent_id:, organization_links: {siret: organization_link.siret})
      .where.not(id: id)
    errors.add(:organization_link, :siret_already_attached) if clash.exists?
  end
end
