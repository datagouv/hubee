# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :data_stream
  belongs_to :organization

  delegate :uuid, to: :data_stream, prefix: true
  delegate :siret, to: :organization, prefix: true

  enum :permission_type, {
    read: "read",
    write: "write",
    read_write: "read_write"
  }

  validates :permission_type, presence: true
  validates :data_stream_id, uniqueness: {scope: :organization_id}
end
