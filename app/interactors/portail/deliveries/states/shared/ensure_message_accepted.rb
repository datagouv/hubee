# frozen_string_literal: true

module Portail
  module Deliveries
    module States
      module Shared
        # Le message contre le réglage du flux, relu au moment d'écrire : une page vieillie ne
        # publie pas ce que le flux n'accepte plus.
        class EnsureMessageAccepted
          include Interactor

          def call
            return if context.message.nil?

            refusal = refusal_for(HubAPI::DataStreams.fetch(context.delivery.data_stream_code))
            context.fail!(error: refusal) if refusal
          end

          private

          def refusal_for(data_stream)
            return :unavailable if data_stream.nil?
            return :message_not_accepted unless data_stream.v1.allows_message_with_state_change?

            :message_too_long if context.message.length > Portail::Delivery::StateMessage::MAX_LENGTH
          end
        end
      end
    end
  end
end
