# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :data_stream
  belongs_to :organization

  has_many :notifications, dependent: :restrict_with_error

  scope :by_data_stream, ->(id) { id.present? ? where(data_stream_id: id) : all }
  scope :by_organization, ->(id) { id.present? ? where(organization_id: id) : all }
  scope :with_read_permission, -> { where(can_read: true) }
  scope :with_write_permission, -> { where(can_write: true) }
  scope :by_can_read, ->(value) {
    return all if value.nil?

    where(can_read: ActiveModel::Type::Boolean.new.cast(value))
  }
  scope :by_can_write, ->(value) {
    return all if value.nil?

    where(can_write: ActiveModel::Type::Boolean.new.cast(value))
  }

  validates :data_stream_id, uniqueness: {scope: :organization_id}
  validate :at_least_one_permission

  private

  def at_least_one_permission
    return if can_read? || can_write?

    errors.add(:base, "must have at least one permission (can_read or can_write)")
  end
end
