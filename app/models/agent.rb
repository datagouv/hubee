# frozen_string_literal: true

class Agent < ApplicationRecord
  # === Associations ===
  has_many :memberships, dependent: :destroy
  has_many :organization_links, through: :memberships

  # === Validations ===
  validates :provider_sub, presence: true, uniqueness: true
  validates :email, presence: true
end
