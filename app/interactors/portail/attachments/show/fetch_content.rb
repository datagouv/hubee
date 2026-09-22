# frozen_string_literal: true

module Portail
  module Attachments
    class Show
      # Les octets, entièrement en mémoire, qui ne font que traverser : ni journal, ni magasin.
      # La récupération est inscrite à l'historique du télédossier par la frontière, qui ne rend
      # rien si elle n'a pas pu l'écrire : aucun fichier n'est remis sans trace.
      class FetchContent
        include Interactor

        def call
          context.body = HubAPI::Attachments.download(delivery_id:, id: attachment_id,
            filename:, author:, siret: link.siret, insee_code: link.insee_code)
          # La trace amont atteste que le portail a retiré le fichier ; celle-ci, que cet agent
          # l'a demandé. L'identifiant et pas le nom : la supervision tourne sans donnée personnelle.
          Rails.logger.info("Pièce récupérée", delivery_id:, id: attachment_id, agent_id: context.agent.id)
        rescue HubAPI::EventLimitReached
          # L'amont ne peut plus rien inscrire sur ce dossier : un état durable, pas un incident,
          # et une issue à part — réessayer n'y changerait rien.
          Rails.logger.warn("Historique du télédossier saturé", delivery_id:, id: attachment_id)
          context.fail!(error: :event_limit_reached)
        rescue HubAPI::NotFound
          # L'inventaire disait reçue, l'amont ne la sert plus : l'inventaire a vieilli.
          Rails.logger.info("Pièce non livrable", delivery_id:, id: attachment_id, reason: :gone_upstream)
          context.fail!(error: :not_found)
        rescue HubAPI::Error => e
          # Panne et contenu non servi sont déjà signalés par la frontière : un même mode dégradé.
          Rails.logger.error("Pièce indisponible", delivery_id:, id: attachment_id, error: e.class.name)
          context.fail!(error: :unavailable)
        end

        private

        def delivery_id = context.delivery.id

        def attachment_id = context.attachment.id

        # Le périmètre du rattachement, que le verbe d'écriture rejoue avant de tracer : un agent
        # ne trace que sur les dossiers servis à son organisation.
        def link = context.membership.organization_link

        # « Prénom Nom », adresse en repli : les deux noms sont nullables en base, l'adresse non.
        # Règle du portail, jamais de la frontière, qui ne connaît ni l'agent ni la session.
        def author
          agent = context.agent

          [agent.first_name, agent.last_name].compact_blank.join(" ").presence || agent.email
        end

        # Le nom BRUT du déposant, jamais l'assaini : la lecture V1 apparie par égalité stricte.
        # Vide, il retombe sur le repli — la ligne ne s'appariera alors à aucune pièce, c'est su.
        def filename
          return context.attachment.filename if context.attachment.filename.present?

          Rails.logger.warn("Pièce sans nom tracée sous un nom de repli", delivery_id:, id: attachment_id)
          Delivery::Attachment::FALLBACK_FILENAME
        end
      end
    end
  end
end
