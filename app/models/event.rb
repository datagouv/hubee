# frozen_string_literal: true

# Trace immuable d'une action, écrite par le système et jamais par un appelant. Elle survit à
# ses sujets : un agent supprimé ne doit pas emporter la preuve de ce qu'on lui a accordé.
class Event < ApplicationRecord
  # === Constants ===
  # Liste fermée : un type inventé au fil de l'eau échapperait à la purge, et une trace sans
  # échéance ne s'efface jamais.
  TYPES = %w[
    agent.created
    agent.updated
    membership.created
    membership.updated
    membership.detached
  ].freeze

  # Trois ans : une trace d'habilitation répond à « qui a ouvert cet accès » longtemps après
  # coup. À six mois, la question la plus probable d'un audit tombe déjà hors fenêtre.
  RETENTION = 3.years

  # === Associations ===
  # `optional` sans être facultatif : les colonnes sont exigées par les validations, mais aucune
  # clé étrangère ne les tient — le sujet peut disparaître, la trace reste.
  belongs_to :eventable, polymorphic: true, optional: true

  # === Validations ===
  validates :eventable_id, :eventable_type, presence: true
  validates :event_type, inclusion: {in: TYPES}
  # Premier niveau universel — qui écrit, ce qui a changé (avant → après). `subject` porte les
  # faits propres au type, dans leur état d'APRÈS : l'avant vit exclusivement dans `changes`.
  validate :metadata_names_its_writer
  validate :metadata_identifies_its_subject
  validate :metadata_details_updates

  # === Scopes ===
  scope :expired, -> { where(created_at: ..RETENTION.ago) }

  # === Méthodes ===
  # Signature stable et nommée, et un seul endroit à changer si la forme d'écriture évolue :
  # la contrainte, elle, est tenue par les validations.
  def self.record!(eventable, type:, metadata:)
    create!(eventable: eventable, event_type: type, metadata: metadata)
  end

  # Une trace réécrite ne prouve rien. `destroy` est refusé au passage : seule la purge, qui
  # passe par `delete_all`, en supprime.
  def readonly?
    persisted?
  end

  private

  def metadata_names_its_writer
    errors.add(:metadata, :api_client_missing) if metadata.to_h["api_client"].blank?
  end

  def metadata_identifies_its_subject
    errors.add(:metadata, :subject_missing) if metadata.to_h["subject"].blank?
  end

  # Une trace de correction qui ne dit pas ce qu'elle a corrigé ne répond à rien.
  def metadata_details_updates
    return unless event_type.to_s.end_with?(".updated")

    errors.add(:metadata, :changes_missing) if metadata.to_h["changes"].blank?
  end
end
