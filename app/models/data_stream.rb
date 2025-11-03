class DataStream < ApplicationRecord
  belongs_to :owner_organization, class_name: "Organization"
  has_many :subscriptions, dependent: :destroy
  has_many :data_packages, dependent: :restrict_with_error

  validates :name, presence: true
  validates :retention_days, numericality: {greater_than: 0}, allow_nil: true
end
