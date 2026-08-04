FactoryBot.define do
  factory :agent do
    sequence(:provider_sub) { |n| "proconnect-sub-#{n}" }
    sequence(:email) { |n| "agent#{n}@example.gouv.fr" }
    first_name { "Camille" }
    last_name { "Martin" }
  end
end
