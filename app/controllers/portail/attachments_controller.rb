# frozen_string_literal: true

module Portail
  # Le contenu d'une pièce d'une démarche. Une seule action, et rien à rendre : la réponse est le
  # fichier lui-même.
  class AttachmentsController < Portail::BaseController
    # Quand rien du nom d'origine ne survit.
    FALLBACK_FILENAME = "piece"

    # Un seul callback pour les deux : la pièce se cherche dans la démarche, l'ordre est ici.
    before_action :set_delivery_and_attachment, only: :show

    def show
      # Sans cette ligne, un identifiant connu livrerait une pièce hors habilitation. L'accès à
      # une pièce est celui de sa démarche, et la policy vérifie aussi l'organisation servie.
      authorize(@delivery, :show?)

      result = Attachments::Show.call(delivery: @delivery, attachment: @attachment)
      return render_failure(result.error) unless result.success?

      # `attachment` et un type neutre : le type annoncé par l'amont ne décide pas qu'un fichier
      # s'ouvre dans l'onglet de l'agent. Le contenu ne fait que traverser, sous `no-store`.
      send_data(result.body, filename: download_filename(@attachment),
        type: "application/octet-stream", disposition: "attachment")
    end

    private

    # `performed?` : la démarche a pu rendre son refus, la pièce ne se cherche pas dans le vide.
    def set_delivery_and_attachment
      set_delivery
      set_attachment unless performed?
    end

    # Mêmes refus que le détail. Rien à autoriser tant qu'aucune démarche n'est trouvée.
    def set_delivery
      result = Deliveries::Show.call(membership: current_membership, id: params[:demarche_id])

      if result.success?
        @delivery = result.delivery
      else
        skip_authorization
        render_failure(result.error)
      end
    end

    # Parmi les pièces du dépôt seulement : une pièce ajoutée ensuite vit sur son événement, hors
    # de cette adresse. Un identifiant que la démarche ne porte pas, malformé compris, vaut
    # introuvable, sans rien à autoriser ni à demander à l'amont.
    def set_attachment
      @attachment = @delivery.attachments.find { |candidate| candidate.id == params[:id] }
      return if @attachment

      skip_authorization
      Rails.logger.info("Pièce non livrable", delivery_id: @delivery.id, id: params[:id], reason: :unknown)
      not_found
    end

    # Les mêmes pages que le détail : ce qui ne se livre pas est introuvable, le reste est en panne.
    def render_failure(error) = (error == :not_found) ? not_found : unavailable

    # Le nom arrive verbatim du partenaire et finit sur le disque de l'agent. Les caractères de
    # contrôle et de mise en forme partent d'abord : un octet nul ferait lever `basename`, et
    # une inversion de sens d'écriture ferait passer un `.exe` pour un `.pdf`. Puis seul le
    # dernier segment survit, antislash compris. Le modèle, lui, garde le nom brut.
    def download_filename(attachment)
      name = File.basename(attachment.filename.to_s.gsub(/[\p{Cc}\p{Cf}]/, "").tr("\\", "/"))

      name.delete(".").blank? ? FALLBACK_FILENAME : name
    end
  end
end
