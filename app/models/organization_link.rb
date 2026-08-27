# frozen_string_literal: true

# Référence vers une organisation du référentiel V1, identifiée par le couple
# (SIRET, code INSEE) : un SIRET peut porter plusieurs organisations.
# Ne porte aucune copie de l'organisation : le nom d'affichage sera lu en direct.
class OrganizationLink < ApplicationRecord
  # === Constants ===
  # Format INSEE, redéclaré plutôt qu'emprunté à Organization : ce modèle appartient à
  # l'API V2 gelée, on ne s'y couple pas pour une ligne.
  SIRET_FORMAT = /\A\d{14}\z/

  # === Associations ===
  has_many :memberships, dependent: :restrict_with_error
  has_many :agents, through: :memberships

  # === Validations ===
  # Le SIRET est la clé de jointure vers le référentiel V1 : mal formé, le lien ne
  # correspondra jamais à rien et l'agent sera refusé sans qu'on sache pourquoi.
  validates :siret, presence: true, uniqueness: {scope: :insee_code}, format: {with: SIRET_FORMAT}

  validates :insee_code, presence: true
end
