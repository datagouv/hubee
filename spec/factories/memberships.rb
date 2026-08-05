FactoryBot.define do
  factory :membership do
    agent
    organization_link

    trait :local_administrator do
      role { "local_administrator" }
    end
  end
end
