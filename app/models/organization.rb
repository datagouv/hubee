class Organization < ApplicationRecord
  SIRET_FORMAT = /\A\d{14}\z/

  validates :name, presence: true
  validates :siret, presence: true, uniqueness: {case_sensitive: false},
    format: {with: SIRET_FORMAT, message: "must be 14 digits"}
end
