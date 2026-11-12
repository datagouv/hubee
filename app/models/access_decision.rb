# frozen_string_literal: true

# Ce que le portail a décidé, et sur quelles bases. Table d'audit : personne ne la lit
# pendant une requête, et elle survit à la suppression de ses sujets.
class AccessDecision < ApplicationRecord
  # === Constants ===
  # Un an : six mois ne suffisaient pas pour remonter un incident ou répondre à un audit. Durée
  # validée par le métier, la même que pour les traces d'audit de l'API (Event::RETENTION).
  RETENTION = 1.year

  # === Enums ===
  enum :outcome, {granted: "granted", denied: "denied"}, validate: true

  # === Scopes ===
  scope :expired, -> { where(created_at: ..RETENTION.ago) }
end
