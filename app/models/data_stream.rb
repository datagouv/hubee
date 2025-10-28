class DataStream < ApplicationRecord
  belongs_to :owner_organization, class_name: "Organization"

  validates :name, presence: true
  validates :owner_organization, presence: true
  validates :retention_days, numericality: {greater_than: 0}, allow_nil: true
end
