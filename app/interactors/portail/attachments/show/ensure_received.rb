# frozen_string_literal: true

module Portail
  module Attachments
    class Show
      # Livrabilité, pas accès : une pièce d'une démarche lisible reste consultable dans tous ses
      # états, mais seule une pièce reçue a un contenu à remettre.
      class EnsureReceived
        include Interactor

        def call
          return if context.attachment.received?

          # En champs, pas dans le message : les identifiants se filtrent au journal.
          Rails.logger.info("Pièce non livrable",
            delivery_id: context.delivery.id, id: context.attachment.id, reason: :not_received)
          context.fail!(error: :not_found)
        end
      end
    end
  end
end
