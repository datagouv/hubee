# Le cas standard : un membre habilité sur un flux, d'une organisation du référentiel.
FactoryBot.define do
  factory :api_internal_agent_form, class: "API::Internal::AgentForm" do
    sequence(:email) { |n| "agent-api#{n}@ville.fr" }
    first_name { "Alice" }
    last_name { "Martin" }
    siret { "21750056000016" }
    insee_code { "75056" }
    role { "member" }
    data_stream_codes { ["CERTDC"] }

    skip_create
    initialize_with { new(**attributes) }

    trait :local_administrator do
      role { "local_administrator" }
      data_stream_codes { [] }
    end
  end
end
