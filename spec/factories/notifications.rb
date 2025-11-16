# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    association :data_package
    association :subscription
    acknowledged_at { nil }

    trait :acknowledged do
      acknowledged_at { Time.current }
    end
  end
end
