# frozen_string_literal: true

# L'authentification ProConnect attachée à un navigateur, et ce que HubEE en a décidé.
# Sans rattachement, c'est une authentification refusée : ProConnect a bien identifié
# l'agent, le portail ne lui a pas ouvert de session.
#
# Modèle propre à ::Portail, qui porte sa politique d'expiration : écart assumé à la
# règle « un modèle AR ne porte que du code commun », en attente d'arbitrage d'équipe.
class ProviderSession < ApplicationRecord
  # === Constants ===
  # L'absolue est alignée sur la session ProConnect (12 h) : plus courte, un clic
  # réauthentifierait en silence (`max-age` non implémenté chez eux). Les deux bornes
  # forcent la réévaluation du rattachement et du niveau à chaque reprise.
  IDLE = 30.minutes
  ABSOLUTE = 12.hours

  # === Chiffrement ===
  # Un JWT porteur de claims d'identité n'a pas à être lisible par qui lit la table.
  encrypts :provider_id_token

  # === Associations ===
  belongs_to :membership, optional: true

  # === Validations ===
  validates :provider_id_token, presence: true
  validates :email, presence: true

  # === Scopes ===
  scope :granted, -> { where.not(membership_id: nil) }
  scope :denied, -> { where(membership_id: nil) }
  scope :expired, -> { granted.where("updated_at < ? OR created_at < ?", IDLE.ago, ABSOLUTE.ago) }

  # === Méthodes d'instance ===
  def granted? = membership_id.present?

  def denied? = !granted?

  def expired?
    Time.current > created_at + ABSOLUTE || Time.current > updated_at + IDLE
  end
end
