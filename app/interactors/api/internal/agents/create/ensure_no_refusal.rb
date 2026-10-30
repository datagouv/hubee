# frozen_string_literal: true

module API
  module Internal
    module Agents
      class Create
        class EnsureNoRefusal
          include Interactor

          def call
            context.fail! if context.form.errors.any? || context.refusals.present? || context.unavailable
          end
        end
      end
    end
  end
end
