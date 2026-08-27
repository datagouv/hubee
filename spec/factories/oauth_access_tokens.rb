# `plaintext_token` n'est lisible que sur l'instance fraîchement créée (tokens hashés).
FactoryBot.define do
  factory :oauth_access_token, class: "Doorkeeper::AccessToken" do
    application factory: :oauth_application
    expires_in { 2.hours.to_i }
  end
end
