# frozen_string_literal: true

module Portail
  class Delivery
    # L'inventaire d'une pièce, jamais son contenu, qui s'obtient par Portail::HubAPI::Attachments.
    # `state` compte : une pièce rejetée est une information que l'agent n'a nulle part ailleurs.
    # `filename` reste celui du déposant, brut : c'est la clé d'appariement de la lecture V1, par
    # égalité stricte. L'assainir appartient au seul point qui l'écrit dans un en-tête.
    #
    # Sous-classe plutôt qu'un `Data.define` nu : une constante assignée dans le bloc de
    # `Data.define` se poserait sur Portail::Delivery, pas sur la pièce.
    class Attachment < Data.define(:id, :filename, :content_type, :byte_size, :kind, :state)
      # Quand rien du nom d'origine ne survit : sur le disque de l'agent comme dans la trace
      # écrite à l'historique. Une seule valeur pour les deux — deux constantes finiraient par
      # diverger, et l'agent verrait un nom que l'historique ne porte pas.
      FALLBACK_FILENAME = "piece"

      # Seul cet état a un contenu à remettre.
      def state_received? = state == "received"
    end
  end
end
