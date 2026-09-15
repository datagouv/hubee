# frozen_string_literal: true

module Portail
  # Le contenu d'une pièce d'une démarche. Une seule action, et rien à rendre : la réponse est le
  # fichier lui-même.
  class AttachmentsController < Portail::BaseController
    # Quand rien du nom d'origine ne survit ; le type déclaré lui donne une extension s'il est connu.
    FALLBACK_FILENAME = "piece"

    before_action :set_delivery, :set_attachment

    def show
      # Sans cette ligne, un identifiant connu livrerait une pièce hors habilitation. La policy
      # juge la pièce par la démarche dans laquelle elle a été lue, organisation comprise.
      authorize(@attachment)

      result = Attachments::Show.call(delivery: @delivery, attachment: @attachment)
      return refuse(result.error) unless result.success?

      # `attachment` et un type neutre : le type annoncé par l'amont ne décide pas qu'un fichier
      # s'ouvre dans l'onglet de l'agent. Le contenu ne fait que traverser, sous `no-store`.
      send_data(result.body, filename: download_filename(@attachment),
        type: "application/octet-stream", disposition: "attachment")
    end

    private

    # La démarche dont on demande une pièce. Mêmes refus que le détail ; l'autorisation, elle,
    # se joue sur la pièce.
    def set_delivery
      result = Deliveries::Show.call(membership: current_membership, id: params[:demarche_id])
      return @delivery = result.delivery if result.success?

      # Rien à autoriser : aucune démarche n'a été trouvée.
      skip_authorization
      refuse(result.error)
    end

    # Parmi les pièces du dépôt seulement : une pièce ajoutée ensuite vit sur son événement, hors
    # de cette adresse. Un identifiant que la démarche ne porte pas, malformé compris, vaut
    # introuvable, sans rien à autoriser ni à demander à l'amont. En champs, pour le journal.
    def set_attachment
      @attachment = @delivery.attachments.find { |candidate| candidate.id == params[:id] }
      return if @attachment

      skip_authorization
      Rails.logger.info("Pièce non livrable", delivery_id: @delivery.id, id: params[:id], reason: :unknown)
      not_found
    end

    # Les mêmes pages que le détail : ce qui ne se livre pas est introuvable, le reste est en panne.
    def refuse(error) = (error == :not_found) ? not_found : unavailable

    # Le nom arrive verbatim du partenaire et finit sur le disque de l'agent : seul le dernier
    # segment survit, antislash compris, sans caractère de contrôle. Ici et nulle part ailleurs :
    # le nom porté par le modèle est la clé d'appariement de la lecture V1, et reste brut.
    def download_filename(attachment)
      name = File.basename(attachment.filename.to_s.tr("\\", "/")).gsub(/[[:cntrl:]]/, "")

      name.delete(".").blank? ? fallback_filename(attachment) : name
    end

    # Le type déclaré vient aussi du partenaire, sans contrôle : seule une extension que Rails
    # connaît pour ce type est écrite, jamais le type lui-même.
    def fallback_filename(attachment)
      [FALLBACK_FILENAME, Mime::Type.lookup(attachment.content_type.to_s).symbol].compact.join(".")
    end
  end
end
