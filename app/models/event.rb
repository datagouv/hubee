# frozen_string_literal: true

# Trace d'audit RGS. Immuable par readonly? seul, sans garde en base : delete y échappe, même sur
# une instance chargée, comme toute écriture qui n'en passe pas par une (update_all, insert_all,
# delete_all, SQL…). Seule la purge en use, par delete_all.
class Event < ApplicationRecord
  # === Constants ===
  # Un an : la conservation en base que le RGS impose aux événements d'audit.
  RETENTION = 1.year

  TYPES = %w[agent.created membership.created].freeze

  # === Associations ===
  belongs_to :eventable, polymorphic: true

  # === Validations ===
  validates :event_type, inclusion: {in: TYPES}

  # === Scopes ===
  scope :expired, -> { where(created_at: ..RETENTION.ago) }

  # === Méthodes d'instance ===
  def readonly? = persisted? || super
end
