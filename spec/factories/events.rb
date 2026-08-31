FactoryBot.define do
  factory :event do
    # Sans `strategy: :create`, `build(:event)` construit un agent non persisté dont l'id est nul,
    # que la validation de présence refuse.
    association :eventable, factory: :agent, strategy: :create
    event_type { "agent.created" }
    metadata { {"api_client" => "hub-api", "subject" => {"email" => "agent@ville.fr"}} }
  end
end
