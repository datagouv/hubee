# frozen_string_literal: true

module API
  module Internal
    module Agents
      class Create
        class CheckOrganization
          include Interactor

          def call
            # Même connue de la V2 : une organisation supprimée en V1 n'y est jamais effacée.
            return unless form.valid_on?(:siret, :insee_code)

            ask_referential
          end

          private

          def form = context.form

          # Une indisponibilité n'est pas un motif : elle ne masque pas ceux déjà établis.
          def ask_referential
            HubAPI::Organizations.verify(siret: form.siret, insee_code: form.insee_code)
          rescue HubAPI::NotFound
            (context.refusals ||= []) << :unknown_organization
          rescue HubAPI::Unavailable => e
            Rails.logger.error("Référentiel des organisations indisponible — #{e.message}")
            context.unavailable = true
          end
        end
      end
    end
  end
end
