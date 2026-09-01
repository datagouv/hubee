# frozen_string_literal: true

# Bouchons rspec-mocks dans les steps : l'app tourne dans le même process que les
# scénarios, un stub de classe est donc vu par le serveur Capybara. Ils simulent ProConnect ;
# l'API amont passe par le client bouchonné de la gem.
require "cucumber/rspec/doubles"
require "hub_api_v1/testing"

World(FactoryBot::Syntax::Methods)
World(HubApiV1::Testing::Factories)

# La racine renvoie l'agent connecté sur ses démarches : tout scénario qui se connecte traverse
# donc l'API amont. Le client bouchonné de la gem la neutralise sans stubber aucune de nos
# classes. Reposé à chaque scénario pour qu'aucun cas ajouté par l'un ne fuite vers le suivant.
Before do
  HubApiV1.client = HubApiV1::Testing::FakeClient.new
end

After do
  HubApiV1.reset_client!
end

# L'organisation de l'agent E2E, dans le vocabulaire de l'amont : le client bouchonné filtre
# les dossiers sur ce couple, comme le fait l'API.
module DeliveryWorld
  def e2e_recipient = build_v2_recipient(siret: E2E_SIRET, code_insee: "00001")
end

World(DeliveryWorld)
