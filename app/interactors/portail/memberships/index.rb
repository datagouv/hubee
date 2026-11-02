# frozen_string_literal: true

module Portail
  module Memberships
    class Index
      include Interactor::Organizer

      organize Index::ResolveDataStreams
    end
  end
end
