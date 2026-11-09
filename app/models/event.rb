# frozen_string_literal: true

# Trace d'audit RGS. Immuable par readonly? seul, sans garde en base : delete y échappe, même sur
# une instance chargée, comme toute écriture qui n'en passe pas par une (update_all, insert_all,
# delete_all, SQL…). Seule la purge en use, par delete_all.
class Event < ApplicationRecord
  # === Constants ===
  # Un an : la conservation en base que le RGS impose aux événements d'audit.
  RETENTION = 1.year

  # Liste fermée en Ruby seulement, sans enum PostgreSQL : elle grandira à chaque nouvelle trace.
  TYPES = %w[agent.created agent.invited membership.created].freeze

  # === Associations ===
  belongs_to :eventable, polymorphic: true

  # === Validations ===
  validates :event_type, inclusion: {in: TYPES}

  # === Scopes ===
  scope :expired, -> { where(created_at: ..RETENTION.ago) }

  # === Méthodes d'instance ===
  def readonly? = persisted? || super

  # `inspect` et `pp` passent tous deux par ici. `filter_attributes` ne vise que le nom d'une colonne :
  # les clés de `metadata` suivent la liste que l'application applique à ses journaux.
  def attribute_for_inspect(attr_name)
    return super unless attr_name.to_s == "metadata" && metadata.is_a?(Hash)

    ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(metadata).inspect
  end
end
