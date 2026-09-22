# frozen_string_literal: true

module Portail
  module Attachments
    class Show
      # Les octets, entièrement en mémoire, qui ne font que traverser : ni journal, ni magasin.
      class Download
        include Interactor

        def call
          # L'émetteur du dossier doit pouvoir identifier qui a retiré la pièce : sans nom, on
          # n'écrit pas, donc on ne remet rien. Même règle que le changement d'état.
          return context.fail!(error: :unknown_author) if author.blank?

          context.body = HubAPI::Attachments.download(delivery_id:, id: attachment_id,
            filename:, author:, siret: link.siret, insee_code: link.insee_code)
          # L'identifiant et pas le nom : la supervision tourne sans donnée personnelle.
          Rails.logger.info("Pièce récupérée", delivery_id:, id: attachment_id, agent_id: agent.id)
        rescue HubAPI::Error => e
          context.fail!(error: failure_for(e))
        end

        private

        # Panne et contenu non servi sont déjà signalés par la frontière : ici, seulement le
        # journal. Chaque branche rend le symbole que le contrôleur traduit.
        def failure_for(error)
          case error
          when HubAPI::EventLimitReached then saturated
          when HubAPI::NotFound then gone_upstream
          when HubAPI::ContentUnavailable then content_unavailable
          else unavailable(error)
          end
        end

        # L'amont a répondu, sans les octets, et ne dit pas si la pièce est purgée ou son stockage
        # en panne : ni une panne du service, ni une absence. L'agent doit lire cette nuance.
        def content_unavailable
          Rails.logger.warn("Pièce non remise", delivery_id:, id: attachment_id, reason: :content_unavailable)
          :content_unavailable
        end

        def saturated
          Rails.logger.warn("Historique du télédossier saturé", delivery_id:, id: attachment_id)
          :event_limit_reached
        end

        # L'inventaire disait reçue, l'amont ne la sert plus : l'inventaire a vieilli.
        def gone_upstream
          Rails.logger.info("Pièce non livrable", delivery_id:, id: attachment_id, reason: :gone_upstream)
          :not_found
        end

        def unavailable(error)
          Rails.logger.error("Pièce indisponible", delivery_id:, id: attachment_id, error: error.class.name)
          :unavailable
        end

        def delivery_id = context.delivery.id

        def attachment_id = context.attachment.id

        def link = context.membership.organization_link

        def agent = context.membership.agent

        # Même signature que les autres événements écrits en amont. Jamais l'adresse en repli :
        # elle serait publiée chez le partenaire déposant.
        def author = EventAuthor.for(agent)

        # Le nom BRUT, jamais l'assaini : la lecture V1 apparie par égalité stricte.
        def filename
          return context.attachment.filename if context.attachment.filename.present?

          Rails.logger.warn("Pièce sans nom tracée sous un nom de repli", delivery_id:, id: attachment_id)
          Delivery::Attachment::FALLBACK_FILENAME
        end
      end
    end
  end
end
