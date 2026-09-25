# frozen_string_literal: true

module Portail
  module Deliveries
    module Archives
      class Show
        # La liste des pièces vient du détail borné, jamais de la requête : l'amont ne revérifie le
        # périmètre qu'à l'écriture de la trace.
        class Download
          include Interactor

          def call
            # Même règle que la pièce seule : sans nom, on n'écrit pas, donc on ne remet rien.
            return context.fail!(error: :unknown_author) if author.blank?

            context.archive_filename = context.delivery.archive_filename
            context.archive = HubAPI::Attachments.download_all(delivery: context.delivery,
              archive_filename: context.archive_filename, author:, siret: link.siret, insee_code: link.insee_code)
            Rails.logger.info("Pièces récupérées en archive", delivery_id:, agent_id: agent.id,
              attachment_ids: context.delivery.received_attachments.map(&:id))
          rescue HubAPI::Error => e
            context.fail!(error: failure_for(e))
          end

          private

          def failure_for(error)
            case error
            when HubAPI::EventLimitReached then saturated
            when HubAPI::NotFound then gone_upstream
            when HubAPI::ContentUnavailable then content_unavailable
            else unavailable(error)
            end
          end

          def content_unavailable
            Rails.logger.warn("Archive non remise", delivery_id:, reason: :content_unavailable)
            :content_unavailable
          end

          def saturated
            Rails.logger.warn("Historique du télédossier saturé", delivery_id:)
            :event_limit_reached
          end

          # Une pièce que l'amont ne sert plus, ou un télédossier qu'il refuse à l'écriture.
          def gone_upstream
            Rails.logger.info("Archive non livrable", delivery_id:, reason: :gone_upstream)
            :not_found
          end

          def unavailable(error)
            Rails.logger.error("Archive indisponible", delivery_id:, error: error.class.name)
            :unavailable
          end

          def delivery_id = context.delivery.id

          def link = context.membership.organization_link

          def agent = context.membership.agent

          def author = EventAuthor.for(agent)
        end
      end
    end
  end
end
