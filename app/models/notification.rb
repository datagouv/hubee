class Notification < ApplicationRecord
  belongs_to :data_package
  belongs_to :subscription

  validates :subscription_id, uniqueness: {scope: :data_package_id}
  validate :subscription_belongs_to_same_data_stream

  scope :transmitted, -> { where(acknowledged_at: nil) }
  scope :acknowledged, -> { where.not(acknowledged_at: nil) }

  def acknowledge!
    update!(acknowledged_at: Time.current)
  end

  def acknowledged?
    acknowledged_at.present?
  end

  private

  def subscription_belongs_to_same_data_stream
    return unless subscription && data_package

    if subscription.data_stream_id != data_package.data_stream_id
      errors.add(:subscription, "must belong to the same data_stream as data_package")
    end
  end
end
