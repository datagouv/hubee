# frozen_string_literal: true

# L'authentification ProConnect attachée à un navigateur, et ce que HubEE en a décidé.
# Sans rattachement, c'est une authentification refusée : ProConnect a bien identifié
# l'agent, le portail ne lui a pas ouvert de session.
#
# Pas de scope d'expiration ici : les bornes sont une politique du portail.
class ProviderSession < ApplicationRecord
  # === Associations ===
  belongs_to :membership, optional: true

  # === Validations ===
  validates :provider_id_token, presence: true
  validates :email, presence: true

  # === Scopes ===
  scope :granted, -> { where.not(membership_id: nil) }
  scope :denied, -> { where(membership_id: nil) }

  # === Méthodes d'instance ===
  def granted? = membership_id.present?
end
