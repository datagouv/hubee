# frozen_string_literal: true

# Référence vers une organisation du référentiel V1, identifiée par son SIRET.
# Ne porte aucune copie de l'organisation : le nom d'affichage sera lu en direct.
class OrganizationLink < ApplicationRecord
  # === Associations ===
  has_many :memberships, dependent: :restrict_with_error
  has_many :agents, through: :memberships

  # === Validations ===
  validates :siret, presence: true, uniqueness: true
end
