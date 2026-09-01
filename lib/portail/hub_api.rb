# frozen_string_literal: true

module Portail
  # La couche de traduction avec la gem cliente. Le portail n'appelle jamais la gem
  # directement : il passe par ici, et ne connaît en retour que ses propres modèles et ces
  # erreurs-ci.
  module HubAPI
    class Error < StandardError; end

    # L'amont n'a pas répondu, ou pas de façon exploitable. Les appelants dégradent.
    class Unavailable < Error; end

    # La démarche n'existe pas, ou elle est hors du périmètre d'organisation interrogé. Les
    # deux cas se confondent à dessein : les distinguer confirmerait l'existence d'un dossier
    # que l'agent n'a pas à voir.
    class NotFound < Error; end

    # L'amont a refusé un paramètre avant tout aller-retour réseau — typiquement un état ou
    # une page trafiqués dans l'URL. Le refus est montré à l'agent plutôt que corrigé en
    # silence : un filtre qui se réinitialise tout seul ment sur ce qui est affiché.
    class InvalidRequest < Error; end
  end
end
