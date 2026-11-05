# `redirect_uri` volontairement absent : blank autorisé quand seul client_credentials
# est actif. `plaintext_secret` n'est lisible que sur l'instance fraîchement créée.
FactoryBot.define do
  factory :oauth_application, class: "Doorkeeper::Application" do
    sequence(:name) { |n| "client-#{n}" }

    trait :with_agent_registration_right do
      after(:create) { create(:oauth_application_right, oauth_application: it) }
    end
  end
end
