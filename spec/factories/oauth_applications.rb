# `redirect_uri` volontairement absent : blank autorisé quand seul client_credentials
# est actif. `plaintext_secret` n'est lisible que sur l'instance fraîchement créée.
FactoryBot.define do
  factory :oauth_application, class: "Doorkeeper::Application" do
    sequence(:name) { |n| "client-#{n}" }
  end
end
