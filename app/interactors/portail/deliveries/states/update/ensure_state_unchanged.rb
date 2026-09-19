# frozen_string_literal: true

module Portail
  module Deliveries
    module States
      class Update
        # La table ne suffit pas : elle laisserait passer « traité » sur un dossier passé « en
        # attente de compléments », que l'agent clôturerait sans voir qu'on attendait des pièces.
        class EnsureStateUnchanged
          include Interactor

          def call
            return if context.seen_state == context.delivery.state

            Rails.logger.info("Changement d'état refusé", id: context.delivery.id,
              seen_state: context.seen_state, state: context.delivery.state, reason: :stale_state)
            context.fail!(error: :stale_state)
          end
        end
      end
    end
  end
end
