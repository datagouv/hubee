# frozen_string_literal: true

# Outillage de la FRONTIÈRE avec la gem : ses stubs et factories ne servent qu'au spec de
# Portail::HubAPI et à l'intégration Cucumber, partout ailleurs le portail ne connaît que ses
# propres modèles. Ne jamais stubber l'API amont avec WebMock ici : son format de fil appartient
# à la gem, et ce dépôt est public.
require "hub_api_v1/testing"

RSpec.configure do |config|
  config.include HubApiV1::Testing::Stubs
  config.include HubApiV1::Testing::Factories
end
