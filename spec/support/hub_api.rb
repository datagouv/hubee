# frozen_string_literal: true

# Stubs et factories fournis par la gem cliente. Ne jamais stubber l'API amont avec WebMock
# ici : son format de fil appartient à la gem, et ce dépôt est public.
require "hub_api_v1/testing"

RSpec.configure do |config|
  config.include HubApiV1::Testing::Stubs
  config.include HubApiV1::Testing::Factories
end
