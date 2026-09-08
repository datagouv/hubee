# frozen_string_literal: true

# Bouchons rspec-mocks dans les steps : l'app tourne dans le même process que les
# scénarios, un stub de classe est donc vu par le serveur Capybara. Ils simulent ProConnect ;
# l'API amont passe par le client bouchonné de la gem.
require "cucumber/rspec/doubles"
require "hub_api_v1/testing"

World(FactoryBot::Syntax::Methods)
World(HubApiV1::Testing::Factories)

# Tout scénario connecté traverse l'API amont. Reposé à chaque scénario pour qu'aucun cas
# ajouté par l'un ne fuite vers le suivant.
Before do
  HubApiV1.client = HubApiV1::Testing::FakeClient.new
end

# Les compteurs de `rate_limit` survivraient d'un scénario à l'autre : la connexion du dernier
# répondrait 429 une fois le seuil atteint par les précédents. Même remise à zéro qu'en RSpec.
Before do
  ActionController::Base.cache_store.clear
end

After do
  HubApiV1.reset_client!
end

# L'organisation de l'agent E2E dans le vocabulaire de l'amont : le client bouchonné filtre
# sur ce couple, comme l'API.
module DeliveryWorld
  def e2e_recipient = build_v2_recipient(siret: E2E_SIRET, code_insee: "00001")
end

World(DeliveryWorld)
