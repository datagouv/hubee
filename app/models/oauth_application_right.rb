# frozen_string_literal: true

# Droit d'un client de l'API sur une opération. Hors des scopes Doorkeeper : un client qui porte un
# scope se voit refuser tout jeton demandé sans lui.
class OauthApplicationRight < ApplicationRecord
  # === Constants ===
  RIGHTS = %w[internal:agents:create].freeze

  # === Associations ===
  belongs_to :oauth_application, class_name: "Doorkeeper::Application"

  # === Validations ===
  validates :right, inclusion: {in: RIGHTS}, uniqueness: {scope: :oauth_application_id}
end
