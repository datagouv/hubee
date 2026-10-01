# frozen_string_literal: true

module Portail
  module Deliveries
    module States
      module Shared
        # L'écriture. Le message de l'agent, s'il en a écrit un, part vers l'émetteur du dossier.
        class WriteState
          include Interactor

          def call
            # Un auteur vide passerait la garde de la gem en « paramètre refusé », qu'on afficherait
            # en panne : l'agent réessaierait sans que rien n'atteigne la supervision.
            return context.fail!(error: :unknown_author) if context.author.blank?

            write_state
          end

          private

          def write_state
            link = context.membership.organization_link
            context.event = HubAPI::Deliveries.change_state(
              id: context.delivery.id, state: context.state, author: context.author,
              message: context.message, siret: link.siret, insee_code: link.insee_code
            )
          rescue HubAPI::Error => e
            context.fail!(error: failure_for(e))
          end

          # Un refus se dit à l'agent tel quel ; un défaut du portail se signale ; une panne se
          # journalise. Chaque branche rend le symbole que le contrôleur traduit.
          def failure_for(error)
            case error
            when HubAPI::NotFound then refused(:not_found)
            when HubAPI::AwaitingAttachmentsNotAllowed then refused(:awaiting_attachments_not_allowed)
            when HubAPI::EventLimitReached then refused(:event_limit_reached)
            when HubAPI::InvalidRequest then rejected(error)
            else unavailable(error)
            end
          end

          def refused(error)
            Rails.logger.info("Changement d'état refusé", id: context.delivery.id, state: context.state, reason: error)
            error
          end

          # L'état et le message sont déjà filtrés : ce refus vient d'un auteur trop long ou d'un
          # rattachement malformé, un défaut du portail et non un geste de l'agent. Signalé, jamais rejoué.
          def rejected(error)
            Rails.error.report(error, handled: true)
            Rails.logger.error("Changement d'état rejeté par l'amont", id: context.delivery.id,
              state: context.state, reason: error.message)
            :rejected
          end

          def unavailable(error)
            Rails.logger.error("Changement d'état impossible — #{error.class} : #{error.message}")
            :unavailable
          end
        end
      end
    end
  end
end
