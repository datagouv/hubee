FactoryBot.define do
  sequence(:denied_session_email) { |n| "agent#{n}@example.gouv.fr" }

  factory :provider_session do
    membership
    # Celle de l'agent pour une session ouverte : le portail ferme celle dont l'adresse n'est plus la sienne.
    email { membership ? membership.agent.email : generate(:denied_session_email) }
    sequence(:provider_id_token) { |n| "id-token-#{n}" }
    amr { ["pwd"] }
    acr { "eidas1" }

    # Une authentification que ProConnect a bien menée, mais que le portail a refusée :
    # ni rattachement, ni agent quand l'adresse ne correspond à personne.
    trait :denied do
      membership { nil }
      denial_reason { "organization_mismatch" }
    end
  end
end
