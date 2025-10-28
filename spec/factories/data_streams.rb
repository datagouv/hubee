FactoryBot.define do
  factory :data_stream do
    name { Faker::Lorem.words(number: 3).join(" ").titleize }
    description { Faker::Lorem.sentence }
    association :owner_organization, factory: :organization
    retention_days { 365 }

    trait :with_custom_retention do
      retention_days { 180 }
    end
  end
end
