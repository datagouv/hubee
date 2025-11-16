class Notification < ApplicationRecord
  belongs_to :data_package
  belongs_to :subscription

  validates :subscription_id, uniqueness: {scope: :data_package_id}

  scope :transmitted, -> { where(acknowledged_at: nil) }
  scope :acknowledged, -> { where.not(acknowledged_at: nil) }

  def acknowledge!
    update!(acknowledged_at: Time.current)
  end

  def acknowledged?
    acknowledged_at.present?
  end
end
