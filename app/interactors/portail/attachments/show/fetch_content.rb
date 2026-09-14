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
          # L'inventaire disait reçue, l'amont ne la sert plus : l'inventaire a vieilli entre la
          # page et le clic. Même vocabulaire que l'étape précédente, sous son propre motif.
          Rails.logger.info("Pièce non livrable", delivery_id:, id: attachment_id, reason: :gone_upstream)
          context.fail!(error: :not_found)
        rescue HubAPI::Error => e
          # Le contenu non servi est déjà journalisé par la frontière, la panne déjà signalée :
          # il ne reste qu'à journaliser et à échouer, sous un même mode dégradé.
          Rails.logger.error("Pièce indisponible — #{e.class} : #{e.message}")
          context.fail!(error: :unavailable)
        end

        private

        def delivery_id = context.delivery.id

        def attachment_id = context.attachment.id
      end
    end
  end
end
