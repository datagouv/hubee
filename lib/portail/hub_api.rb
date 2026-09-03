# frozen_string_literal: true

module Portail
  # La couche de traduction avec la gem cliente : le portail ne connaît que ses propres modèles
  # et ces erreurs-ci.
  module HubAPI
    class Error < StandardError; end

    # L'amont n'a pas répondu, ou pas de façon exploitable.
    class Unavailable < Error; end

    # Inexistante ou hors du périmètre interrogé, à dessein confondus : distinguer confirmerait
    # l'existence d'un dossier que l'agent n'a pas à voir.
    class NotFound < Error; end

    # Paramètre refusé avant tout aller-retour réseau, typiquement un état ou une page trafiqués.
    # Montré à l'agent plutôt que corrigé en silence.
    class InvalidRequest < Error; end
  end
end
