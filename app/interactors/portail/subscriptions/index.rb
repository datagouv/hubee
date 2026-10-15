# frozen_string_literal: true

module Portail
  module Subscriptions
    class Index
      include Interactor::Organizer

      organize Index::FetchList
    end
  end
end
