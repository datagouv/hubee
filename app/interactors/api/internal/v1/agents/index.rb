# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        class Index
          include Interactor::Organizer

          # Les critères refusés, rien ne part : la recherche ne lit que des critères validés.
          organize Index::ValidateCriteria, Index::FetchList
        end
      end
    end
  end
end
