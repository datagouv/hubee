# frozen_string_literal: true

module API
  module Agents
    class Create
      class ValidatePayload
        include Interactor

        # Première étape : un appel invalide échoue avant toute I/O, réseau compris.
        def call
          return if context.payload.valid?

          context.fail!(error: :invalid_payload, fields: context.payload.errors.to_hash)
        end
      end
    end
  end
end
