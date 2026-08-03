# frozen_string_literal: true

# Rattachement d'un agent à une organisation. Accordé délibérément par un producteur
# externe ; le portail ne le crée jamais.
class Membership < ApplicationRecord
  # === Associations ===
  belongs_to :agent
  belongs_to :organization_link

  # === Validations ===
  validates :agent_id, uniqueness: {scope: :organization_link_id}
end
