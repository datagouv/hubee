# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        module Shared
          class ValidatePayload
            include Interactor

            def call
              context.form.validate
            end
          end
        end
      end
    end
  end
end
