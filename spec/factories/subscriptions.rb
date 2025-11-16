# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    association :data_stream
    association :organization
    can_read { true }
    can_write { false }

    trait :read_only do
      can_read { true }
      can_write { false }
    end

    trait :write_only do
      can_read { false }
      can_write { true }
    end

    trait :read_write do
      can_read { true }
      can_write { true }
    end
  end
end
