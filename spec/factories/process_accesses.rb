FactoryBot.define do
  factory :process_access do
    membership
    sequence(:process_code) { |n| "PROC-#{n}" }
  end
end
