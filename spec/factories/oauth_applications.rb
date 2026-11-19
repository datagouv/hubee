# `redirect_uri` volontairement absent : blank autorisé quand seul client_credentials
# est actif. `plaintext_secret` n'est lisible que sur l'instance fraîchement créée.
FactoryBot.define do
  factory :oauth_application, class: "Doorkeeper::Application" do
    sequence(:name) { |n| "client-#{n}" }

    trait :with_agent_registration_right do
      after(:create) { create(:oauth_application_right, oauth_application: it) }
    end

    %i[read update destroy].each do |operation|
      trait :"with_agent_#{operation}_right" do
        after(:create) { create(:oauth_application_right, oauth_application: it, right: "internal:agents:#{operation}") }
      end
    end

    # Le client du portail d'administration : les quatre droits sur les agents.
    trait :admin_portal do
      with_agent_registration_right
      with_agent_read_right
      with_agent_update_right
      with_agent_destroy_right
    end
  end
end
