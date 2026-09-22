# frozen_string_literal: true

module Portail
  # Le contenu d'une pièce d'un télédossier. Une seule action, et rien à rendre : la réponse est le
  # fichier lui-même.
  class AttachmentsController < Portail::BaseController
    # Un seul callback pour les deux : la pièce se cherche dans le télédossier, l'ordre est ici.
    before_action :set_delivery_and_attachment, only: :show

    def show
      # Sans cette ligne, un identifiant connu livrerait une pièce hors habilitation. L'accès à
      # une pièce est celui de son télédossier, et la policy vérifie aussi l'organisation servie.
      authorize(@delivery, :show?)

      # L'agent et son rattachement suivent : la récupération s'inscrit à l'historique du
      # télédossier sous l'identité de la session, et dans le périmètre du rattachement.
      result = Attachments::Show.call(delivery: @delivery, attachment: @attachment,
        membership: current_membership, agent: current_agent)
      return render_failure(result.error) unless result.success?

      # `attachment` et un type neutre : le type annoncé par l'amont ne décide pas qu'un fichier
      # s'ouvre dans l'onglet de l'agent. Le contenu ne fait que traverser, sous `no-store`.
      send_data(result.body, filename: download_filename(@attachment),
        type: "application/octet-stream", disposition: "attachment")
    end

    private

    # `performed?` : le télédossier a pu rendre son refus, la pièce ne se cherche pas dans le vide.
    def set_delivery_and_attachment
      set_delivery
      set_attachment unless performed?
    end

    # Mêmes refus que le détail. Un rendu ici coupe la chaîne, la vérification d'autorisation ne
    # tourne pas : rien à lever.
    def set_delivery
      result = Deliveries::Show.call(membership: current_membership, id: params[:teledossier_id])

      if result.success?
        @delivery = result.delivery
      else
        render_failure(result.error)
      end
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

    # Les mêmes pages que le détail pour deux issues sur trois, et une page à part pour le dossier
    # plein : l'agent ne comprendrait pas une panne là où rien ne se réparera.
    def render_failure(error)
      case error
      when :not_found then not_found
      when :event_limit_reached then event_limit_reached
      else unavailable
      end
    end

    # 409 : c'est l'état de la ressource qui s'oppose à la demande, sans la promesse de réessai
    # que porterait un 503.
    def event_limit_reached
      render("portail/errors/delivery_event_limit_reached", status: :conflict,
        locals: {delivery_path: teledossier_path(@delivery.id)})
    end

    # Le nom arrive verbatim du partenaire et finit sur le disque de l'agent. Les caractères de
    # contrôle et de mise en forme partent d'abord : un octet nul ferait lever `basename`, et
    # une inversion de sens d'écriture ferait passer un `.exe` pour un `.pdf`. Puis seul le
    # dernier segment survit, antislash compris. Le modèle, lui, garde le nom brut.
    def download_filename(attachment)
      name = File.basename(attachment.filename.to_s.gsub(/[\p{Cc}\p{Cf}]/, "").tr("\\", "/"))

      name.delete(".").blank? ? Delivery::Attachment::FALLBACK_FILENAME : name
    end
  end
end
