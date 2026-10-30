FactoryBot.define do
  factory :oauth_application_right do
    oauth_application
    right { "internal:agents:create" }
  end
end
