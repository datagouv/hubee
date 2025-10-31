# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    association :data_stream
    association :organization
    permission_type { :read }

    trait :read_only do
      permission_type { :read }
    end

    trait :write_only do
      permission_type { :write }
    end

    trait :read_write do
      permission_type { :read_write }
    end
  end
end
