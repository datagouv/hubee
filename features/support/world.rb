# frozen_string_literal: true

# Bouchons rspec-mocks dans les steps : l'app tourne dans le même process que les
# scénarios, un stub de classe est donc vu par le serveur Capybara.
require "cucumber/rspec/doubles"

World(FactoryBot::Syntax::Methods)
