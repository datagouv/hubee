# frozen_string_literal: true

module Portail
  # Ce qui vit sous un télédossier le lit comme le détail, avec les mêmes refus.
  module NestedInDelivery
    extend ActiveSupport::Concern

    private

    # Un rendu ici coupe la chaîne, la vérification d'autorisation ne tourne pas : rien à lever.
    def set_delivery
      result = Deliveries::Show.call(membership: current_membership, id: params[:teledossier_id])

      if result.success?
        @delivery = result.delivery
      elsif result.error == :not_found
        not_found
      else
        unavailable
      end
    end
  end
end
