# frozen_string_literal: true

# Stubs et factories fournis par la gem cliente. Ne jamais stubber l'API amont avec WebMock
# ici : son format de fil appartient à la gem, et ce dépôt est public.
require "hub_api_v1/testing"

RSpec.configure do |config|
  config.include HubApiV1::Testing::Stubs
  config.include HubApiV1::Testing::Factories

  # Depuis que la racine renvoie l'agent connecté sur ses démarches, toute spec de requête qui
  # suit une redirection après connexion traverse la liste, donc l'API amont. Ce défaut la
  # neutralise pour celles qui ne s'y intéressent pas ; une spec qui l'éprouve repose son
  # propre stub, qui prend le pas. Cantonné aux specs de requête : ailleurs, un stub global
  # masquerait le comportement même qu'on cherche à vérifier.
  config.before(type: :request) do
    allow(HubApiV1::V2::Delivery).to receive(:list).and_return(build_delivery_list([]))
  end
end
