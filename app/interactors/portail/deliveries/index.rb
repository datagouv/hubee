# frozen_string_literal: true

module Portail
  module Deliveries
    class Index
      include Interactor::Organizer

      organize Index::FetchList
    end
  end
end
