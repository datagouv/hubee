# frozen_string_literal: true

module Portail
  module Deliveries
    class Index
      include Interactor::Organizer

      # Les flux proposés d'abord : ils bornent le flux choisi avant que la liste ne parte.
      organize Index::ResolveDataStreams, Index::FetchList
    end
  end
end
