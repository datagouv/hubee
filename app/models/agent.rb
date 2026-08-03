# frozen_string_literal: true

class Agent < ApplicationRecord
  # === Associations ===
  has_many :memberships, dependent: :destroy
  has_many :organization_links, through: :memberships

  # === Normalisations ===
  # Les fournisseurs d'identité ne garantissent pas la casse : sans ça, un agent enrôlé
  # en « Alice.Martin@… » serait refusé s'il se présente en « alice.martin@… ».
  # `normalizes` s'applique aussi aux arguments des méthodes de recherche.
  normalizes :email, with: ->(email) { email.strip.downcase }

  # === Validations ===
  # Nul tant que l'agent n'a pas ouvert sa première session : c'est ProConnect qui
  # l'attribue à la connexion. Un agent enrôlé existe donc avant d'en avoir un.
  validates :provider_sub, uniqueness: true, allow_nil: true
  validates :email, presence: true
end
