# frozen_string_literal: true

module Portail
  # Le contenu d'une pièce d'une démarche. Une seule action, et rien à rendre : la réponse est le
  # fichier lui-même.
  class AttachmentsController < Portail::BaseController
    # Quand rien du nom d'origine ne survit.
    FALLBACK_FILENAME = "piece"

    before_action :set_delivery

    def show
      result = Attachments::Show.call(delivery: @delivery, id: params[:id])
      return refuse(result.error) unless result.success?

      # `attachment` et un type neutre : le type annoncé par l'amont ne décide pas qu'un fichier
      # s'ouvre dans l'onglet de l'agent. Le contenu ne fait que traverser, sous `no-store`.
      send_data(result.body, filename: download_filename(result.attachment),
        type: "application/octet-stream", disposition: "attachment")
    end

    private

    # La démarche, autorisée avant que sa pièce ne soit demandée : les octets d'une démarche hors
    # habilitation ne sont jamais demandés à l'amont. Mêmes refus que le détail.
    def set_delivery
      result = Deliveries::Show.call(membership: current_membership, id: params[:demarche_id])

      unless result.success?
        # Rien à autoriser : aucune démarche n'a été trouvée.
        skip_authorization
        return refuse(result.error)
      end

      @delivery = authorize(result.delivery, :show?)
    end

    # Les mêmes pages que le détail : ce qui ne se livre pas est introuvable, le reste est en panne.
    def refuse(error) = (error == :not_found) ? not_found : unavailable

    # Le nom arrive verbatim du partenaire et finit sur le disque de l'agent : seul le dernier
    # segment survit, antislash compris, sans caractère de contrôle. Ici et nulle part ailleurs :
    # le nom porté par le modèle est la clé d'appariement de la lecture V1, et reste brut.
    def download_filename(attachment)
      name = File.basename(attachment.filename.to_s.tr("\\", "/")).gsub(/[[:cntrl:]]/, "")

      name.delete(".").blank? ? FALLBACK_FILENAME : name
    end
  end
end
