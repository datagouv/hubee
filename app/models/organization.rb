class Organization < ApplicationRecord
  SIRET_FORMAT = /\A\d{14}\z/

  has_many :data_streams, foreign_key: :owner_organization_id, dependent: :restrict_with_error
  has_many :subscriptions, dependent: :destroy
  has_many :transmitted_data_packages, class_name: "DataPackage", foreign_key: :sender_organization_id, dependent: :restrict_with_error

  validates :name, presence: true
  validates :siret, presence: true, uniqueness: {case_sensitive: false},
    format: {with: SIRET_FORMAT, message: "must be 14 digits"}
end
