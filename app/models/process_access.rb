# frozen_string_literal: true

# Habilitation d'un agent, dans une organisation donnée, sur un processus de la V1 désigné
# par son code. Référence, jamais une copie : la V1 n'expose aucun libellé.
#
# Ne vérifie pas que l'organisation est abonnée au processus — l'abonnement vit en V1 et
# ce dépôt ne peut pas le contrôler. C'est un invariant qui engage les producteurs.
class ProcessAccess < ApplicationRecord
  # === Associations ===
  # Pas de `dependent:` — la cascade est portée par la base.
  belongs_to :membership

  # === Normalisations ===
  # Le code est un identifiant opaque : les codes ne sont pas tous en majuscules et
  # certains portent des tirets, rabattre la casse en corromprait.
  normalizes :process_code, with: ->(code) { code.strip }

  # === Validations ===
  # L'unicité est donc sensible à la casse, faute de savoir laquelle de deux formes vaut.
  validates :process_code,
    presence: true,
    format: {with: /\A\S+\z/, allow_blank: true},
    length: {maximum: 100},
    uniqueness: {scope: :membership_id}
end
