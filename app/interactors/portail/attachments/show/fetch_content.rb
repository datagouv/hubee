# frozen_string_literal: true

module Portail
  module Attachments
    class Show
      # Les octets, entièrement en mémoire, qui ne font que traverser : ni journal, ni magasin.
      class FetchContent
        include Interactor

        def call
          context.body = HubAPI::Attachments.download(delivery_id: delivery_id, id: attachment_id)
        rescue HubAPI::NotFound
          # L'inventaire disait reçue, l'amont ne la sert plus : l'inventaire a vieilli.
          Rails.logger.info("Pièce non livrable", delivery_id:, id: attachment_id, reason: :gone_upstream)
          context.fail!(error: :not_found)
        rescue HubAPI::Error => e
          # Panne et contenu non servi sont déjà signalés par la frontière : un même mode dégradé.
          Rails.logger.error("Pièce indisponible", delivery_id:, id: attachment_id, error: e.class.name)
          context.fail!(error: :unavailable)
        end

        private

        def delivery_id = context.delivery.id

        def attachment_id = context.attachment.id
      end
    end
  end
end
