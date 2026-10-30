module API
  module Internal
    # Le filtrage d'adresse est la contrainte de routage de /api/internal : pas de second filtre.
    class BaseController < API::BaseController
    end
  end
end
