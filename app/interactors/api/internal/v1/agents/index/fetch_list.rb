# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        class Index
          class FetchList
            include Interactor

            # Une relation, pas une page : la pagination appartient à la requête HTTP, que seul le
            # controller connaît.
            def call
              context.agents = AgentsQuery.new.call(**context.form.criteria)
            end
          end
        end
      end
    end
  end
end
