# frozen_string_literal: true

module Portail
  module Deliveries
    # L'archive des pièces reçues d'un télédossier. Une seule action, et rien à rendre : la réponse
    # est le zip lui-même. Mêmes refus que la pièce seule.
    class ArchivesController < Portail::BaseController
      include NestedInDelivery
      include DownloadRefusals

      # `send_data` chargerait l'archive entière ; sans `to_path`, le serveur ne la cherche pas sur
      # le disque et ce corps la lit par blocs. La frontière la rend rembobinée.
      class Body
        CHUNK_SIZE = 64.kilobytes

        def initialize(archive)
          @archive = archive
        end

        def each
          while (chunk = @archive.read(CHUNK_SIZE))
            yield chunk
          end
        end
      end

      before_action :set_delivery, only: :show

      def show
        # Sans cette ligne, un identifiant connu livrerait les pièces d'un télédossier hors
        # habilitation.
        authorize(@delivery, :show?)

        result = Archives::Show.call(delivery: @delivery, membership: current_membership)
        unless result.success?
          return render_failure(result.error, subject: :archive,
            unknown_author_alert: "portail.deliveries.archives.unknown_author")
        end

        send_archive(result.archive, result.archive_filename)
      end

      private

      # Confiée d'abord à `Rack::TempfileReaper`, qui la supprime à la fermeture de la réponse ou
      # sur toute erreur qui la précède. `sending_file` après le type, comme `send_data` : avant,
      # Rails y remettrait un charset.
      def send_archive(archive, filename)
        request.env[Rack::RACK_TEMPFILES] << archive
        self.content_type = "application/zip"
        response.sending_file = true
        headers["Content-Disposition"] =
          ActionDispatch::Http::ContentDisposition.format(disposition: "attachment", filename:)
        headers["Content-Length"] = archive.size.to_s
        self.response_body = Body.new(archive)
      end
    end
  end
end
