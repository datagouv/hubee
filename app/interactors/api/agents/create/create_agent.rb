# frozen_string_literal: true

module API
  module Agents
    class Create
      class CreateAgent
        include Interactor

        def call
          context.agent = Agent.create!(
            email: payload.email, first_name: payload.first_name,
            last_name: payload.last_name, civility: payload.civility
          )
        rescue ActiveRecord::RecordNotUnique
          # Course entre deux appels : l'index unique tranche là où la validation ne voit rien.
          context.fail!(error: :email_taken)
        rescue ActiveRecord::RecordInvalid => e
          error = e.record.errors.of_kind?(:email, :taken) ? :email_taken : :invalid_payload
          context.fail!(error: error, fields: e.record.errors.to_hash)
        end

        private

        def payload
          context.payload
        end
      end
    end
  end
end
