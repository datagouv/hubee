# frozen_string_literal: true

# Outillage de la frontière avec la gem. Ne jamais stubber l'API amont avec WebMock ici : son
# format de fil appartient à la gem, et ce dépôt est public.
require "hub_api_v1/testing"

RSpec.configure do |config|
  config.include HubApiV1::Testing::Stubs
  config.include HubApiV1::Testing::Factories
end
