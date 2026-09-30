# frozen_string_literal: true

module Portail
  module Deliveries
    module States
      module Shared
        # La cible est-elle proposée depuis l'état courant, flux et récupération compris ? La même
        # règle que la liste des états proposés à l'agent sur la page du télédossier, une seule
        # source. Vérifiée avant d'écrire pour ne pas envoyer en amont un geste voué au refus.
        class EnsureTransitionAllowed
          include Interactor

          def call
            data_stream = HubAPI::DataStreams.fetch(delivery.data_stream_code)
            return if Access::StateTransitions.offered_from(delivery, data_stream).include?(context.state)

            context.fail!(error: refusal(data_stream))
          end

          private

          def delivery = context.delivery

          def refusal(data_stream)
            if Access::StateTransitions.withheld_by_stream(delivery.state, data_stream).include?(context.state)
              :state_not_allowed_by_stream
            elsif Access::StateTransitions.withheld_until_retrieved(delivery, data_stream).include?(context.state)
              :attachments_not_retrieved
            else
              :invalid_request
            end
          end
        end
      end
    end
  end
end
