# frozen_string_literal: true

# Outillage de la FRONTIÈRE avec la gem. Les stubs et factories qu'elle fournit ne servent
# qu'au spec de Portail::HubAPI et à l'intégration Cucumber : partout ailleurs, le portail ne
# connaît que ses propres modèles. Ne jamais stubber l'API amont avec WebMock ici : son format
# de fil appartient à la gem, et ce dépôt est public.
require "hub_api_v1/testing"

# Les scopes attendus par l'API amont sont de la configuration de déploiement, lue par la gem à
# la construction de son client. Les specs n'ont pas à connaître leurs vraies valeurs : des noms
# neutres suffisent, et évitent d'inscrire ceux du realm dans ce dépôt public. HUB_API_SCOPE est
# le repli des deux autres et reste obligatoire.
ENV["HUB_API_SCOPE"] ||= "test-scope"
ENV["HUB_API_REFERENTIAL_SCOPE"] ||= "test-referential-scope"
ENV["HUB_API_TELESERVICES_SCOPE"] ||= "test-teleservices-scope"

RSpec.configure do |config|
  config.include HubApiV1::Testing::Stubs
  config.include HubApiV1::Testing::Factories
end
