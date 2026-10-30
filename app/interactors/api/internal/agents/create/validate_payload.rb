# frozen_string_literal: true

module API
  module Internal
    module Agents
      class Create
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
