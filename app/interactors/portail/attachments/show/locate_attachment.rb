# frozen_string_literal: true

module Portail
  module Attachments
    class Show
      # La pièce dans l'inventaire déjà servi, parmi celles du dépôt initial seulement : une pièce
      # ajoutée ensuite vit sur son événement, hors du périmètre de cette adresse. Rien ne part
      # vers l'amont d'ici, y compris pour un identifiant malformé, qui n'y est simplement pas.
      class LocateAttachment
        include Interactor

        # Seul cet état a un contenu : les autres restent consultables, mais ne se récupèrent pas.
        DELIVERABLE_STATE = "received"

        def call
          attachment = context.delivery.attachments.find { |candidate| candidate.id == context.id }

          not_found(:unknown) if attachment.nil?
          not_found(:not_received) unless attachment.state == DELIVERABLE_STATE

          context.attachment = attachment
        end

        private

        # En champs, pas dans le message : les identifiants se filtrent au journal, et `reason`
        # sépare la pièce que la démarche ne porte pas de l'état qui l'empêche.
        def not_found(reason)
          Rails.logger.info("Pièce non livrable", delivery_id: context.delivery.id, id: context.id, reason:)
          context.fail!(error: :not_found)
        end
      end
    end
  end
end
