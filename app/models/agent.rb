# frozen_string_literal: true

class Agent < ApplicationRecord
  # === Validations ===
  validates :provider_sub, presence: true, uniqueness: true
  validates :email, presence: true
end
