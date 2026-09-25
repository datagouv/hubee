# frozen_string_literal: true

module Portail
  module Deliveries
    # L'archive des pièces reçues d'un télédossier. Une seule action, et rien à rendre : la réponse
    # est le zip lui-même. Mêmes refus que la pièce seule.
    class ArchivesController < Portail::BaseController
      include NestedInDelivery

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

      # Avant la lecture du télédossier : rien à lire pour une requête qui ne remet rien.
      before_action :refuse_head, only: :show
      before_action :set_delivery, only: :show

      def show
        # Sans cette ligne, un identifiant connu livrerait les pièces d'un télédossier hors
        # habilitation.
        authorize(@delivery, :show?)

        result = Archives::Show.call(delivery: @delivery, membership: current_membership)
        return render_failure(result.error) unless result.success?

        send_archive(result.archive, result.archive_filename)
      end

      private

      # 405 et non un 200 vide : assembler l'archive pour en donner les en-têtes la tracerait
      # sans la remettre.
      def refuse_head
        head(:method_not_allowed, allow: "GET") if request.head?
      end

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

      def render_failure(error)
        case error
        when :not_found then not_found
        when :event_limit_reached then event_limit_reached
        when :content_unavailable then content_unavailable
        when :unknown_author then redirect_to teledossier_path(@delivery.id),
          alert: t("portail.deliveries.archives.unknown_author")
        else unavailable
        end
      end

      # 409 et non 503 : l'état de la ressource s'oppose à la demande, aucun réessai n'y changera rien.
      def event_limit_reached
        render("portail/errors/delivery_event_limit_reached", status: :conflict,
          locals: {delivery_path: teledossier_path(@delivery.id), subject: :archive})
      end

      # 503, faute de savoir : l'amont ne distingue pas une pièce purgée d'un stockage en panne. La
      # page le dit à l'agent au lieu d'annoncer un service qui ne répond pas.
      def content_unavailable
        render("portail/errors/attachment_content_unavailable", status: :service_unavailable,
          locals: {delivery_path: teledossier_path(@delivery.id), subject: :archive})
      end
    end
  end
end
