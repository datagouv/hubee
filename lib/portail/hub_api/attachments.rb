# frozen_string_literal: true

# La gem vit dans un groupe hors `default` : Bundler ne l'auto-requiert pas.
require "hub_api_v1"

module Portail
  module HubAPI
    # Le contenu des pièces d'un télédossier. Ni l'état de la pièce, ni sa taille, ni les droits de
    # l'agent ne sont regardés ici : ce sont des décisions de l'appelant, prises avant l'appel.
    module Attachments
      class << self
        # Deux appels amont sous un seul nom, et l'ordre porte l'invariant : rien n'est tracé sans
        # octets servis, rien n'est rendu sans trace. Soudure d'un manque de hub-api V1, à retirer
        # le jour où l'amont tracera seul.
        def download(delivery_id:, id:, filename:, author:, siret:, insee_code:,
          client: HubApiV1.client)
          content = fetch(delivery_id, id, client)
          record(delivery_id, filename, author, siret, insee_code, client)
          content
        end

        private

        # Les octets tels que l'amont les sert, en BINARY et entièrement en mémoire. Ils traversent
        # sans être ni conservés ni journalisés.
        def fetch(delivery_id, id, client)
          HubApiV1::V2::Attachment.download(delivery_id: delivery_id, id: id, client: client)
        rescue HubApiV1::V2::AttachmentUnavailableError => e
          # L'amont rend la même réponse pour une pièce purgée et pour une panne de la route :
          # seule la fréquence de cette ligne distingue l'une de l'autre. Message stable, à compter.
          Rails.logger.warn("Contenu de pièce non servi par l'amont", delivery_id: delivery_id, attachment_id: id)
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
      end
    end
  end
end
