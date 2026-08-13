# frozen_string_literal: true

# Bouchons rspec-mocks dans les steps : l'app tourne dans le même process que les
# scénarios, un stub de classe est donc vu par le serveur Capybara.
require "cucumber/rspec/doubles"
require "hub_api_v1/testing"

World(FactoryBot::Syntax::Methods)
World(HubApiV1::Testing::Factories)

# Depuis que la racine renvoie l'agent connecté sur ses démarches, tout scénario qui se
# connecte traverse la liste, donc l'API amont. Ce défaut la neutralise : ce qui est éprouvé
# ici est le parcours en vrai navigateur, pas le contenu de la liste.
Before do
  allow(HubApiV1::V2::Delivery).to receive(:list).and_return(build_delivery_list([]))
end
