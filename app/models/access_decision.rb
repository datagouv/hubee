# frozen_string_literal: true

# Ce que le portail a décidé, et sur quelles bases. Table d'audit : personne ne la lit
# pendant une requête, et elle survit à la suppression de ses sujets.
class AccessDecision < ApplicationRecord
  # === Constants ===
  # Six mois : ce que la CNIL retient pour les journaux de connexion.
  RETENTION = 6.months

  # === Enums ===
  enum :outcome, {granted: "granted", denied: "denied"}, validate: true

  # === Scopes ===
  scope :expired, -> { where(created_at: ..RETENTION.ago) }
end
