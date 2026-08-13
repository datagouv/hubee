# frozen_string_literal: true

module Portail
  # Les scopes OAuth2 que l'API amont attend, route par route. Ce sont des noms définis par le
  # fournisseur de jetons de notre déploiement : ils appartiennent donc à ce dépôt, pas à la gem
  # cliente, qui se contente de transmettre ce qu'on lui passe.
  #
  # Rassemblés ici plutôt que lus à l'endroit de chaque appel : consulter une démarche traverse
  # deux routes aux scopes différents, et disperser ces lectures rendrait la prochaine erreur de
  # configuration aussi coûteuse à diagnostiquer que la première.
  module HubAPIScopes
    module_function

    # Le référentiel — organisations, abonnements, processus.
    def referential = ENV.fetch("HUB_API_SCOPE_REFERENTIAL")

    # Les téléservices — les démarches elles-mêmes.
    def teleservices = ENV.fetch("HUB_API_SCOPE")
  end
end
