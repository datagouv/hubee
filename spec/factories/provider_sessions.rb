FactoryBot.define do
  factory :provider_session do
    membership
    sequence(:email) { |n| "agent#{n}@example.gouv.fr" }
    sequence(:provider_id_token) { |n| "id-token-#{n}" }
    amr { ["pwd"] }

    # Une authentification que ProConnect a bien menée, mais que le portail a refusée :
    # ni rattachement, ni agent quand l'adresse ne correspond à personne.
    trait :denied do
      membership { nil }
      denial_reason { "organization_mismatch" }
    end
  end
end
