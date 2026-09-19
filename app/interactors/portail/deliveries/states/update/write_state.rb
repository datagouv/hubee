# frozen_string_literal: true

module Portail
  module Deliveries
    module States
      class Update
        # L'écriture. Le texte joint part vers l'émetteur du dossier, qui le lit : il nomme l'état
        # d'arrivée comme le fait déjà l'historique, pour ne pas dépareiller.
        class WriteState
          include Interactor

          def call
            # Un auteur vide passerait la garde de la gem en « paramètre refusé », qu'on afficherait
            # en panne : l'agent réessaierait sans que rien n'atteigne la supervision.
            return context.fail!(error: :unknown_author) if context.author.blank?

            text = event_text
            return missing_text if text.nil?

            write_state(text)
          end

          private

          def write_state(text)
            link = context.membership.organization_link
            context.event = HubAPI::Deliveries.change_state(
              id: context.delivery.id, state: context.state, author: context.author,
              message: text, siret: link.siret, insee_code: link.insee_code
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

          # L'état est déjà filtré : ce refus vient d'un auteur trop long ou d'un rattachement
          # malformé, un défaut du portail et non un geste de l'agent. Signalé, jamais rejoué.
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

          def event_text
            I18n.t("portail.deliveries.change_state.event_messages.#{context.state}", default: nil)
          end

          # Plutôt échouer que publier « translation missing » à l'émetteur du dossier.
          def missing_text
            Rails.logger.error("Texte d'événement manquant", state: context.state)
            context.fail!(error: :unavailable)
          end
        end
      end
    end
  end
end
