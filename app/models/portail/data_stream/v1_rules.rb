# frozen_string_literal: true

module Portail
  class DataStream
    # Ce que le flux accepte d'une pièce du service instructeur : une règle V1 sans équivalent V2.
    class V1Rules < Data.define(:attachment_states, :attachment_content_types, :attachment_max_byte_size)
      # Sans format ni taille, le flux ne peut rien accepter : autant ne rien proposer.
      def attachable_from?(state)
        attachment_states.include?(state) && attachment_content_types.any? && attachment_max_byte_size.positive?
      end

      def accepts_content_type?(content_type) = attachment_content_types.include?(content_type)

      def accepts_byte_size?(byte_size) = byte_size <= attachment_max_byte_size
    end
  end
end
