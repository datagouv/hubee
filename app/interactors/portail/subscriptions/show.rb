# frozen_string_literal: true

module Portail
  module Subscriptions
    class Show
      include Interactor::Organizer

      organize Show::FindSubscription
    end
  end
end
