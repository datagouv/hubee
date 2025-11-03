FactoryBot.define do
  factory :data_package do
    association :data_stream
    association :sender_organization, factory: :organization
    state { :draft }

    trait :draft do
      state { :draft }
    end

    trait :transmitted do
      state { :transmitted }
      sent_at { Time.current }
    end

    trait :acknowledged do
      state { :acknowledged }
      sent_at { 1.day.ago }
      acknowledged_at { Time.current }
    end

    trait :with_title do
      title { "Custom-Package-#{SecureRandom.alphanumeric(4).upcase}" }
    end
  end
end
