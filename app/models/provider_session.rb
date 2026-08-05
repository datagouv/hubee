# frozen_string_literal: true

# L'authentification ProConnect attachée à un navigateur, et ce que HubEE en a décidé.
# Sans rattachement, c'est une authentification refusée : ProConnect a bien identifié
# l'agent, le portail ne lui a pas ouvert de session.
#
# Enregistrement propre à ::Portail : il porte lui-même sa politique d'expiration, qu'un
# module satellite obligerait à écrire deux fois, en Ruby et en SQL. Écart assumé à la
# règle « un modèle AR ne porte que du code commun aux deux modules », en attente
# d'arbitrage.
class ProviderSession < ApplicationRecord
  # === Constants ===
  # Deux bornes indépendantes. L'absolue est alignée sur la session ProConnect, de douze
  # heures : plus courte, elle serait sans effet — un clic réauthentifie en silence tant
  # que celle-ci vit, et `max-age`, qui corrigerait ça, n'est pas implémenté côté
  # ProConnect. Ce qu'elles garantissent : le rattachement et le niveau sont réévalués à
  # chaque reprise.
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
