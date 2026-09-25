# frozen_string_literal: true

module Portail
  # Le contenu d'une pièce d'un télédossier. Une seule action, et rien à rendre : la réponse est le
  # fichier lui-même.
  class AttachmentsController < Portail::BaseController
    include NestedInDelivery
    include DownloadRefusals

    # Un seul callback pour les deux : la pièce se cherche dans le télédossier, l'ordre est ici.
    before_action :set_delivery_and_attachment, only: :show

    def show
      # Sans cette ligne, un identifiant connu livrerait une pièce hors habilitation. L'accès à
      # une pièce est celui de son télédossier, et la policy vérifie aussi l'organisation servie.
      authorize(@delivery, :show?)

      result = Attachments::Show.call(delivery: @delivery, attachment: @attachment,
        membership: current_membership)
      unless result.success?
        return render_failure(result.error, subject: :attachment,
          unknown_author_alert: "portail.deliveries.attachments.unknown_author")
      end

      # `attachment` et un type neutre : le type annoncé par l'amont ne décide pas qu'un fichier
      # s'ouvre dans l'onglet de l'agent. Le contenu ne fait que traverser, sous `no-store`.
      send_data(result.body, filename: SafeFilename.for(@attachment.filename),
        type: "application/octet-stream", disposition: "attachment")
    end

    private

    # `performed?` : le télédossier a pu rendre son refus, la pièce ne se cherche pas dans le vide.
    def set_delivery_and_attachment
      set_delivery
      set_attachment unless performed?
    end

    # Parmi les pièces du dépôt seulement : une pièce ajoutée ensuite vit sur son événement, hors
    # de cette adresse. Un identifiant que le télédossier ne porte pas, malformé compris, vaut
    # introuvable, sans rien à autoriser ni à demander à l'amont.
    def set_attachment
      @attachment = @delivery.attachments.find { |candidate| candidate.id == params[:id] }
      return if @attachment

      Rails.logger.info("Pièce non livrable", delivery_id: @delivery.id, id: params[:id], reason: :unknown)
      not_found
    end
  end
end
