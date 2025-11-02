class DataStream < ApplicationRecord
  belongs_to :owner_organization, class_name: "Organization"
  has_many :subscriptions, dependent: :destroy

  validates :name, presence: true
  validates :retention_days, numericality: {greater_than: 0}, allow_nil: true
end
