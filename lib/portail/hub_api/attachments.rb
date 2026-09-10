# frozen_string_literal: true

# La gem vit dans un groupe hors `default` : Bundler ne l'auto-requiert pas.
require "hub_api_v1"

module Portail
  module HubAPI
    # Le contenu des pièces. La lecture est bornée EN AMONT, par la gem, sur les trois dimensions
    # à la fois — organisation, état, flux : la décision d'habilitation doit précéder le
    # rapatriement de l'octet, faute de quoi un refus laisserait derrière lui la trace d'un
    # téléchargement que l'agent n'avait pas le droit de faire.
    #
    # ⚠️ Ce que la trace ne peut PAS dire, et qu'aucune écriture ne corrigera. L'amont interdit
    # d'attacher une pièce à un événement de téléchargement : le nom de fichier, seul, porte le
    # rattachement. Or rien ne rend ce nom unique dans une démarche — une pièce du dépôt et une
    # pièce arrivée ensuite peuvent être homonymes. Deux conséquences pour qui lit l'historique :
    # une trace ne désigne pas laquelle des homonymes a été récupérée, et un lecteur qui apparie
    # par le nom les marquera toutes. Lever l'ambiguïté demanderait de changer la lecture des deux
    # côtés — enrichir le nom, lui, ferait échouer l'appariement sur TOUTES les pièces.
    module Attachments
      class << self
        # `author` n'est pas un ornement : la gem inscrit le téléchargement à l'historique dans le
        # même geste, et refuse un auteur blanc. Une trace anonyme ne tracerait rien.
        def download(delivery_id:, id:, author:, siret:, insee_code:, data_stream_codes:,
          client: HubApiV1.client)
          content = HubApiV1::V2::Attachment.download(
            delivery_id: delivery_id,
            id: id,
            author: author,
            siret: siret,
            # `code_insee` en amont, `insee_code` ici : la couture vit à la frontière.
            code_insee: insee_code,
            data_stream_codes: data_stream_codes,
            client: client
          )

          Portail::Delivery::AttachmentContent.new(
            # Les modèles du portail, traduits par la frontière voisine : un seul jeu de modèles,
            # une seule lecture du contrat.
            delivery: Deliveries.delivery_from(content.delivery),
            attachment: Deliveries.attachment_from(content.attachment),
            body: content.body
          )
        rescue HubApiV1::Error => e
          raise translated(e)
        end

        private

        # La classe d'origine reste dans le message : c'est elle qui distingue une panne d'un
        # refus au journal.
        def translated(error)
          case error
          when HubApiV1::V2::AttachmentNotFoundError then AttachmentNotFound.new(error.message)
          # Comptée par la gem sur la démarche qu'elle relit, AVANT de rapatrier l'octet : on ne
          # paie pas le transfert d'un fichier qu'on ne pourra ni tracer ni, donc, servir.
          when HubApiV1::V2::DeliveryEventLimitReachedError then HistoryFull.new(error.message)
          # Pas de rapport d'erreur, à dessein : l'amont ne sait pas distinguer une pièce disparue
          # d'une panne, et le plus courant des deux est le premier. Signaler chaque occurrence
          # noierait le rapporteur ; c'est leur volume qui parle, et le journal le porte.
          when HubApiV1::V2::AttachmentUnavailableError then AttachmentUnavailable.new(error.message)
          # Les quatre causes du bornage — organisation, état, flux, identifiant inconnu — que la
          # gem confond à dessein. Le portail ne cherche pas à les rouvrir : sur cette adresse,
          # qui ne s'atteint qu'après un détail légitimement consulté, toutes sont anormales.
          when HubApiV1::V2::DeliveryNotFoundError then NotFound.new(error.message)
          when HubApiV1::V2::InvalidArgumentError then InvalidRequest.new(error.message)
          else
            # Une panne est un incident, signalé ici et non par chaque appelant : un seul point,
            # avec l'exception d'origine. Le portail ne nomme pas Sentry, abonné au rapporteur.
            Rails.error.report(error, handled: true)
            Unavailable.new("#{error.class} : #{error.message}")
          end
        end
      end
    end
  end
end
