# frozen_string_literal: true

# La gem vit dans un groupe hors `default` : Bundler ne l'auto-requiert pas.
require "hub_api_v1"

module Portail
  module HubAPI
    # Le contenu des pièces d'un télédossier, remis avec la trace de sa récupération.
    module Attachments
      class << self
        # Deux appels amont sous un seul nom, et l'ordre porte l'invariant : rien n'est tracé sans
        # octets servis, rien n'est rendu sans trace. Soudure d'un manque de hub-api V1, à retirer
        # le jour où l'amont tracera seul. Ni l'état de la pièce, ni sa taille, ni les droits de
        # l'agent ne sont regardés : décisions de l'appelant, prises avant l'appel.
        def download(delivery_id:, id:, filename:, author:, siret:, insee_code:,
          client: HubApiV1.client)
          content = fetch(delivery_id, id, client)
          record(delivery_id, filename, author, siret, insee_code, client)
          content
        end

        # Le zip des pièces reçues, fermé puis tracé avant d'être rendu, une pièce en mémoire à la fois ;
        # à supprimer par l'appelant après l'envoi. `delivery` doit venir de la lecture bornée du détail
        # ET avoir passé la policy : la trace ne rejoue que l'organisation, pas l'habilitation. Une
        # erreur d'écriture du fichier remonte non traduite.
        def download_all(delivery:, archive_filename:, author:, siret:, insee_code:, client: HubApiV1.client)
          attachments = delivery.received_attachments
          raise InvalidRequest, "No received attachment in delivery #{delivery.id}" if attachments.empty?

          file = Tempfile.new("archive", binmode: true)
          Archive.write(file, File.basename(archive_filename, ".zip")) do |archive|
            attachments.each { |attachment| add_content(archive, delivery.id, attachment, client) }
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

        # Rendue à l'allocateur dès son écriture : la pièce suivante ne s'ajoute pas à elle en mémoire.
        def add_content(archive, delivery_id, attachment, client)
          content = fetch(delivery_id, attachment.id, client)
          archive.add(attachment.filename, content)
          content.clear unless content.frozen?
        end

        # Les octets tels que l'amont les sert, en BINARY et entièrement en mémoire. Ils traversent
        # sans être ni conservés ni journalisés.
        def fetch(delivery_id, id, client)
          HubApiV1::V2::Attachment.download(delivery_id: delivery_id, id: id, client: client)
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
