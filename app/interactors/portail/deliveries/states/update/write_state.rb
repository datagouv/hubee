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
            # Deux refus qui doivent se dire à l'agent, pas se déguiser en panne : sans eux, la
            # gem refuse et on lui promet un réessai qui ne marchera jamais.
            return context.fail!(error: :unknown_author) if context.author.blank?

            message = event_message
            return missing_message if message.nil?

            write(message)
          end

          private

          def write(message)
            link = context.membership.organization_link
            context.event = HubAPI::Deliveries.change_state(
              id: context.delivery.id, state: context.state, author: context.author,
              message: message, siret: link.siret, insee_code: link.insee_code
            )
          rescue HubAPI::NotFound
            refuse(:not_found)
          rescue HubAPI::AwaitingDocumentsNotAllowed
            refuse(:awaiting_documents_not_allowed)
          rescue HubAPI::EventLimitReached
            refuse(:event_limit_reached)
          rescue HubAPI::InvalidRequest => e
            # L'état est déjà filtré : ce refus vient d'un auteur trop long ou d'un rattachement
            # malformé, un défaut du portail et non un geste de l'agent. Signalé, jamais rejoué.
            Rails.error.report(e, handled: true)
            Rails.logger.error("Changement d'état rejeté par l'amont", id: context.delivery.id,
              state: context.state, reason: e.message)
            context.fail!(error: :rejected)
          rescue HubAPI::Error => e
            Rails.logger.error("Changement d'état impossible — #{e.class} : #{e.message}")
            context.fail!(error: :unavailable)
          end

          def event_message
            I18n.t("portail.deliveries.change_state.event_messages.#{context.state}", default: nil)
          end

          # Plutôt échouer que publier « translation missing » à l'émetteur du dossier.
          def missing_message
            Rails.logger.error("Texte d'événement manquant", state: context.state)
            context.fail!(error: :unavailable)
          end

          def refuse(error)
            Rails.logger.info("Changement d'état refusé",
              id: context.delivery.id, state: context.state, reason: error)
            context.fail!(error: error)
          end
        end
      end
    end
  end
end
