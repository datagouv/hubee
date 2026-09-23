# frozen_string_literal: true

module Portail
  class DataStream
    # Ce que le flux accepte d'une pièce du service instructeur : une règle V1 sans équivalent V2.
    class V1Rules < Data.define(:states_allowing_attachment, :attachment_content_types, :attachment_max_byte_size)
      def allows_attachment_from?(state) = states_allowing_attachment.include?(state)

      def accepts_content_type?(content_type) = attachment_content_types.include?(content_type)

      def accepts_byte_size?(byte_size) = byte_size <= attachment_max_byte_size
    end
  end
end
