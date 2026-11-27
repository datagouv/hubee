# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        class Update
          # L'adresse résout l'agent à la connexion : deux agents ne la partagent pas. Le contrôle de
          # Save, par l'index unique, rattrape un appel simultané.
          class CheckEmailAvailability
            include Interactor

            def call
              return unless form.email_changed? && form.valid_on?(:email)

              (context.refusals ||= []) << :email_taken if Agent.where(email: form.email).where.not(id: form.agent.id).exists?
            end

            private

            def form = context.form
          end
        end
      end
    end
  end
end
