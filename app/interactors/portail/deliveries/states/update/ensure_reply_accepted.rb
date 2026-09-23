# frozen_string_literal: true

module Portail
  module Deliveries
    module States
      class Update
        # La réponse contre les règles du flux, relues au moment d'écrire : une page vieillie ne
        # publie pas ce que le flux n'accepte plus.
        class EnsureReplyAccepted
          include Interactor

          def call
            return if reply.nil?

            refusal = refusal_for(HubAPI::DataStreams.fetch(context.delivery.data_stream_code))
            context.fail!(error: refusal) if refusal
          end

          private

          def reply = context.reply

          # Sans règles lisibles, rien ne part : une réponse ne se publie que sur un accord explicite.
          def refusal_for(data_stream)
            return :unavailable if data_stream.nil?
            return :attachment_not_accepted unless data_stream.v1.attachable_from?(context.delivery.state)

            content_refusal(data_stream.v1)
          end

          def content_refusal(v1_attachment_rules)
            return :attachment_empty if reply.byte_size.zero?
            return :attachment_format unless v1_attachment_rules.accepts_content_type?(reply.content_type)
            return :attachment_too_large unless v1_attachment_rules.accepts_byte_size?(reply.byte_size)

            :attachment_filename unless reply.filename.length.between?(1, Portail::Delivery::Reply::MAX_FILENAME_LENGTH)
          end
        end
      end
    end
  end
end
