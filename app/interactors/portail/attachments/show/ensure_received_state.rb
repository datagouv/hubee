# frozen_string_literal: true

module Portail
  module Attachments
    class Show
      # Livrabilité, pas accès : une pièce reste consultable dans tous ses états, seule une
      # pièce reçue a un contenu à remettre.
      class EnsureReceivedState
        include Interactor

        def call
          return if context.attachment.state_received?

          Rails.logger.info("Pièce non livrable",
            delivery_id: context.delivery.id, id: context.attachment.id, reason: :not_received)
          context.fail!(error: :not_found)
        end
      end
    end
  end
end
