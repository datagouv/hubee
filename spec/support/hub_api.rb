# frozen_string_literal: true

# Stubs et factories fournis par la gem cliente. Ne jamais stubber l'API amont avec WebMock
# ici : son format de fil appartient à la gem, et ce dépôt est public.
require "hub_api_v1/testing"

# Les scopes attendus par l'API amont sont de la configuration de déploiement, désormais lue
# par la gem à la construction de son client. Les specs n'ont pas à connaître leurs vraies
# valeurs : des noms neutres suffisent, et évitent d'inscrire ceux du realm dans ce dépôt
# public. HUB_API_SCOPE est le repli des deux autres et reste obligatoire.
ENV["HUB_API_SCOPE"] ||= "test-scope"
ENV["HUB_API_REFERENTIAL_SCOPE"] ||= "test-referential-scope"
ENV["HUB_API_TELESERVICES_SCOPE"] ||= "test-teleservices-scope"

RSpec.configure do |config|
  config.include HubApiV1::Testing::Stubs
  config.include HubApiV1::Testing::Factories

  # Depuis que la racine renvoie l'agent connecté sur ses démarches, toute spec de requête qui
  # suit une redirection après connexion traverse la liste, donc l'API amont. Ce défaut la
  # neutralise pour celles qui ne s'y intéressent pas ; une spec qui l'éprouve repose son
  # propre stub, qui prend le pas. Cantonné aux specs de requête : ailleurs, un stub global
  # masquerait le comportement même qu'on cherche à vérifier.
  config.before(type: :request) do
    allow(HubApiV1::V2::Delivery).to receive(:list).and_return(build_v2_delivery_list([]))
  end
end
