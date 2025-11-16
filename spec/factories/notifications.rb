# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    transient do
      shared_data_stream { nil }
    end

    data_package { association :data_package, data_stream: shared_data_stream || create(:data_stream) }
    subscription { association :subscription, data_stream: data_package.data_stream }
    acknowledged_at { nil }

    trait :acknowledged do
      acknowledged_at { Time.current }
    end
  end
end
