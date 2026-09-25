# frozen_string_literal: true

module Portail
  module Deliveries
    module Archives
      class Show
        # Une archive vide ne se trace pas : sans pièce reçue, rien ne part vers l'amont.
        class EnsureReceivedAttachments
          include Interactor

          def call
            return if context.delivery.received_attachments.any?

            Rails.logger.info("Archive non livrable",
              delivery_id: context.delivery.id, reason: :no_received_attachment)
            context.fail!(error: :not_found)
          end
        end
      end
    end
  end
end
