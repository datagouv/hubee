# frozen_string_literal: true

module Portail
  class Delivery
    # Une pièce se lit si la démarche dans laquelle elle a été lue se lit : même règle que le
    # détail, jugée sur la pièce. Son état n'est pas une question d'accès mais de livrabilité,
    # portée par la pièce elle-même.
    class AttachmentPolicy
      attr_reader :membership, :attachment

      def initialize(membership, attachment)
        @membership = membership
        @attachment = attachment
      end

      def show? = DeliveryPolicy.readable?(membership, attachment.delivery)
    end
  end
end
