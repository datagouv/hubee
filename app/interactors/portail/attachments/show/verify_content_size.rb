# frozen_string_literal: true

module Portail
  module Attachments
    class Show
      # Contrôle de fidélité, pas d'accès. Relevé au contrat hub-api le 2026-09-14 : la taille
      # annoncée par l'inventaire ne change plus après le dépôt, et l'amont la compare lui-même
      # au binaire, à l'ingestion comme à la lecture. Ce qui reste hors de sa garde, c'est le
      # transfert : la réponse part sans longueur annoncée, et un corps coupé en route arrive
      # avec un statut de succès. On le fait pour ça, un fichier tronqué remis comme entier.
      # Un fichier étranger d'une autre taille s'y prendrait aussi, mais l'amont l'a déjà refusé.
      class VerifyContentSize
        include Interactor

        # L'amont a servi un contenu d'une autre taille que celle qu'il annonce pour cette pièce.
        class UnexpectedSize < StandardError; end

        def call
          received = context.body.bytesize
          return if received == expected

          # Un incident amont, signalé avec les deux tailles. Les octets ne sortent pas d'ici.
          Rails.logger.error("Contenu de pièce d'une taille inattendue",
            delivery_id:, id: attachment_id, expected:, received:)
          Rails.error.report(UnexpectedSize.new("Attachment #{attachment_id} : #{received} bytes, #{expected} expected"),
            handled: true, context: {delivery_id:, attachment_id:, expected:, received:})
          context.fail!(error: :unexpected_size)
        end

        private

        def expected = context.attachment.byte_size

        def delivery_id = context.delivery.id

        def attachment_id = context.attachment.id
      end
    end
  end
end
