FactoryBot.define do
  factory :access_decision do
    outcome { "denied" }
    reason { "unknown_agent" }
    sequence(:email) { |n| "agent#{n}@example.gouv.fr" }
  end
end
