# frozen_string_literal: true

# La gem vit dans un groupe hors `default` : Bundler ne l'auto-requiert pas.
require "hub_api_v1"

module Portail
  module HubAPI
    # Le contenu des pièces d'un télédossier, remis avec la trace de sa récupération.
    module Attachments
      class << self
        # Rien n'est tracé sans octets servis, rien n'est rendu sans trace. `delivery` porte la pièce ;
        # son état, sa taille et les droits de l'agent sont décidés par l'appelant.
        def download(delivery:, id:, filename:, author:, siret:, insee_code:, client: HubApiV1.client)
          content = content_of(delivery, id, client)
          record(delivery.id, filename, author, siret, insee_code, client)
          content
        end

        # Le zip des pièces reçues, tracé avant d'être rendu, à supprimer par l'appelant. `delivery`
        # vient de la lecture bornée ET de la policy : la trace ne rejoue que l'organisation.
        def download_all(delivery:, archive_filename:, author:, siret:, insee_code:, client: HubApiV1.client)
          attachments = delivery.all_received_attachments
          raise InvalidRequest, "No received attachment in delivery #{delivery.id}" if attachments.empty?

          file = Tempfile.new("archive", binmode: true)
          Archive.write(file, File.basename(archive_filename, ".zip")) do |archive|
            attachments.each { |attachment| add_content(archive, delivery, attachment, client) }
          end
          record_all(delivery.id, archive_filename, author, siret, insee_code, client)
          file.tap(&:rewind)
        rescue
          # La copie du descripteur tenue par rubyzip garderait sinon l'espace disque jusqu'au GC.
          file&.truncate(0)
          file&.close!
          raise
        end

        private

        def event_carrying(delivery, id)
          delivery.events.find { |event| event.attachments.any? { |attachment| attachment.id == id } }
        end

        # Rendue à l'allocateur dès son écriture : la pièce suivante ne s'ajoute pas à elle en mémoire.
        def add_content(archive, delivery, attachment, client)
          content = content_of(delivery, attachment.id, client)
          archive.add(attachment.filename, content)
          content.clear unless content.frozen?
        end

        # L'amont sert une pièce ajoutée sur la route de l'événement qui la porte.
        def content_of(delivery, id, client)
          fetch(delivery.id, id) do
            if (event = event_carrying(delivery, id))
              HubApiV1::V2::Attachment.download_from_event(delivery_id: delivery.id, event_id: event.id, id:, client:)
            else
              HubApiV1::V2::Attachment.download(delivery_id: delivery.id, id:, client:)
            end
          end
        end

        # Les octets tels que l'amont les sert, en BINARY et entièrement en mémoire. Ils traversent
        # sans être ni conservés ni journalisés. Le bloc est l'appel de la route qui les sert.
        def fetch(delivery_id, id)
          yield
        rescue HubApiV1::V2::AttachmentUnavailableError => e
          # L'amont rend la même réponse pour une pièce purgée et pour une panne de la route :
          # seule la fréquence de cette ligne distingue l'une de l'autre. Message stable, à compter.
          Rails.logger.warn("Contenu de pièce non servi par l'amont", delivery_id: delivery_id, attachment_id: id)
          raise HubAPI.translated(e)
        rescue HubApiV1::V2::AttachmentNotFoundError => e
          Rails.logger.warn("Pièce introuvable chez l'amont", delivery_id: delivery_id, attachment_id: id)
          raise HubAPI.translated(e)
        rescue HubApiV1::Error => e
          raise HubAPI.translated(e)
        end

        # `notify: false` explicite : c'est une décision, pas un défaut hérité.
        def record(delivery_id, filename, author, siret, insee_code, client)
          HubApiV1::V2::Delivery.record_attachment_download(
            id: delivery_id, filename: filename, author: author, siret: siret,
            code_insee: insee_code, notify: false, client: client
          )
        rescue HubApiV1::Error => e
          raise HubAPI.translated(e)
        end

        # La trace « toutes les pièces » : `filename` y porte le nom de l'archive, pas celui d'une
        # pièce.
        def record_all(delivery_id, filename, author, siret, insee_code, client)
          HubApiV1::V2::Delivery.record_all_attachments_download(
            id: delivery_id, filename: filename, author: author, siret: siret,
            code_insee: insee_code, notify: false, client: client
          )
        rescue HubApiV1::Error => e
          raise HubAPI.translated(e)
        end
      end
    end
  end
end
