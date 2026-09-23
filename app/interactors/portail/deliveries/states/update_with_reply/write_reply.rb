# frozen_string_literal: true

module Portail
  module Deliveries
    module States
      class UpdateWithReply
        # La réponse part avant l'état : refusée, elle laisse le télédossier tel quel.
        class WriteReply
          include Interactor

          def call
            # Même garde que l'écriture de l'état, avant la première écriture irréversible.
            return context.fail!(error: :unknown_author) if context.author.blank?

            publish
          end

          private

          def publish
            link = context.membership.organization_link
            context.reply_event = HubAPI::Deliveries.reply_with_attachment(
              id: context.delivery.id, reply: context.reply, author: context.author,
              siret: link.siret, insee_code: link.insee_code
            )
          rescue HubAPI::Error => e
            context.fail!(error: failure_for(e))
          end

          def failure_for(error)
            case error
            when HubAPI::AttachmentContentTypeNotAccepted then refused(:attachment_format)
            when HubAPI::AttachmentInfected then refused(:attachment_infected)
            when HubAPI::AttachmentContentMismatch then refused(:attachment_content_mismatch)
            when HubAPI::NotFound then refused(:not_found)
            when HubAPI::EventLimitReached then refused(:event_limit_reached)
            when HubAPI::InvalidRequest then rejected(error)
            else unconfirmed(error)
            end
          end

          def refused(error)
            Rails.logger.info("Pièce refusée", id: context.delivery.id, reason: error)
            error
          end

          # Les gardes du portail précèdent cet appel : ce refus signale un défaut du portail.
          def rejected(error)
            Rails.error.report(error, handled: true)
            Rails.logger.error("Pièce rejetée par l'amont", id: context.delivery.id, reason: error.message)
            :rejected
          end

          # Une publication peut aboutir malgré l'erreur : l'agent vérifie l'historique avant de
          # relancer.
          def unconfirmed(error)
            Rails.logger.error("Publication de pièce non confirmée — #{error.class} : #{error.message}")
            :attachment_unconfirmed
          end
        end
      end
    end
  end
end
