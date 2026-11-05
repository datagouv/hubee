FactoryBot.define do
  factory :event do
    eventable factory: :agent
    event_type { "agent.created" }
  end
end
