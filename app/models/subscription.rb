# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :data_stream
  belongs_to :organization

  enum :permission_type, {
    read: "read",
    write: "write",
    read_write: "read_write" # je retirerais la permission read_write au profit de la possibilité d'avoir 2 permissions. Soit avec 2 attributs, soit avec deux valuers dans l'attribut de permission.
  }

  scope :by_data_stream, ->(id) { id.present? ? where(data_stream_id: id) : all }
  scope :by_organization, ->(id) { id.present? ? where(organization_id: id) : all }
  scope :with_permission_types, ->(types) {
    return all unless types.is_a?(String) # Raise error maybe ?

    valid_types = types.split(",").map(&:strip).select { |t| permission_types.key?(t) }
    valid_types.any? ? where(permission_type: valid_types) : none
  }

  validates :permission_type, presence: true
  validates :data_stream_id, uniqueness: {scope: :organization_id}
end
