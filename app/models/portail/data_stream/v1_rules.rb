# frozen_string_literal: true

module Portail
  class DataStream
    # Ce que le flux accepte du service instructeur, pièce et message : des règles V1 sans équivalent V2.
    class V1Rules < Data.define(:states_allowing_attachment, :attachment_content_types, :attachment_max_byte_size,
      :allows_message_with_state_change)
      def allows_attachment_from?(state) = states_allowing_attachment.include?(state)

      def accepts_content_type?(content_type) = attachment_content_types.include?(content_type)

      def accepts_byte_size?(byte_size) = byte_size <= attachment_max_byte_size

      def allows_message_with_state_change? = allows_message_with_state_change
    end
  end
end
