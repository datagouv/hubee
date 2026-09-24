# frozen_string_literal: true

module Portail
  class Delivery
    # L'inventaire d'une pièce, jamais son contenu, qui s'obtient par Portail::HubAPI::Attachments.
    # `state` compte : une pièce rejetée est une information que l'agent n'a nulle part ailleurs.
    # `filename` reste celui du déposant, brut : c'est la clé d'appariement de la lecture V1, par
    # égalité stricte. L'assainir appartient à ce qui l'écrit sur le disque de l'agent : l'en-tête
    # de la pièce seule, l'entrée de l'archive.
    #
    # Sous-classe : dans le bloc d'un `Data.define` nu, une constante se poserait sur
    # Portail::Delivery et resterait introuvable.
    class Attachment < Data.define(:id, :filename, :content_type, :byte_size, :kind, :state)
      # Une seule valeur pour l'inventaire, le fichier remis et la trace : deux constantes
      # finiraient par diverger.
      FALLBACK_FILENAME = "piece"

      # Seul cet état a un contenu à remettre.
      def state_received? = state == "received"
    end
  end
end
