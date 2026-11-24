# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        class Index
          class ValidateCriteria
            include Interactor

            # Le form garde ses motifs : le controller les rend avec la 422.
            def call
              context.fail!(error: :invalid_criteria) if context.form.invalid?
            end
          end
        end
      end
    end
  end
end
