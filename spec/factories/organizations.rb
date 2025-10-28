FactoryBot.define do
  factory :organization do
    name { Faker::Company.name }
    sequence(:siret) { |n| format("%014d", n) }
  end
end
