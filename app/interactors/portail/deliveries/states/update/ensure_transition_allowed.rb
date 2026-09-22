# frozen_string_literal: true

module Portail
  module Deliveries
    module States
      class Update
        # La cible est-elle proposée depuis l'état courant, flux compris ? La même règle que la
        # liste des états proposés à l'agent sur la page du télédossier, une seule source. Vérifiée
        # avant d'écrire pour ne pas envoyer en amont un geste voué au refus.
        class EnsureTransitionAllowed
          include Interactor

          def call
            return if offered.include?(context.state)

            context.fail!(error: refusal)
          end

          private

          def delivery = context.delivery

          # Flux illisible : la table seule, l'amont tranchera.
          def offered
            data_stream = HubAPI::DataStreams.fetch(delivery.data_stream_code)
            Access::StateTransitions.offered_from(delivery.state, data_stream)
          end

          # Retenu par le flux plutôt que par la table : l'agent ne lit pas le même message. La
          # seule règle que l'amont fait varier est l'attente de compléments.
          def refusal
            if Access::StateTransitions.allowed_from(delivery.state).include?(context.state)
              :awaiting_attachments_not_allowed
            else
              :invalid_request
            end
          end
        end
      end
    end
  end
end
