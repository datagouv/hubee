# frozen_string_literal: true

# Référence vers une organisation du référentiel V1, identifiée par le couple
# (SIRET, code branche) : un SIRET peut porter plusieurs organisations.
# Ne porte aucune copie de l'organisation : le nom d'affichage sera lu en direct.
class OrganizationLink < ApplicationRecord
  # === Constants ===
  # Format INSEE, redéclaré plutôt qu'emprunté à Organization : ce modèle appartient à
  # l'API V2 gelée, on ne s'y couple pas pour une ligne.
  SIRET_FORMAT = /\A\d{14}\z/

  # Observé au référentiel (2026-08) : 4 à 10 caractères, chiffres, majuscules, tirets.
  # Borne à 20 pour la marge ; hors charset, le code ne matcherait jamais le référentiel.
  BRANCH_CODE_FORMAT = /\A[A-Z0-9-]{1,20}\z/

  # === Associations ===
  has_many :memberships, dependent: :restrict_with_error
  has_many :agents, through: :memberships

  # === Validations ===
  # Le SIRET est la clé de jointure vers le référentiel V1 : mal formé, le lien ne
  # correspondra jamais à rien et l'agent sera refusé sans qu'on sache pourquoi.
  validates :siret, presence: true, uniqueness: {scope: :branch_code}, format: {with: SIRET_FORMAT}

  # Même nature que le SIRET, mais sans format garanti : la garde ne fait qu'écarter
  # ce qui ne peut pas exister au référentiel.
  validates :branch_code, presence: true, format: {with: BRANCH_CODE_FORMAT}
end
