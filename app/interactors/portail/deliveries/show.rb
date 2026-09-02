# frozen_string_literal: true

module Portail
  module Deliveries
    class Show
      include Interactor::Organizer

      organize Show::FindDelivery
    end
  end
end
