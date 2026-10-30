# frozen_string_literal: true

module API
  module Internal
    module Agents
      class Create
        # L'enregistrement crée ce qui manque et ne corrige jamais un rattachement : tout rejeu,
        # identique ou non, est refusé.
        class CheckMemberships
          include Interactor

          def call
            return unless form.valid_on?(:email, :siret, :insee_code)

            # Au plus un rattachement par SIRET : ce code guichet est le seul possible.
            attached_insee_code = OrganizationLink.joins(memberships: :agent)
              .where(siret: form.siret, agents: {email: form.email})
              .pick(:insee_code)
            return if attached_insee_code.nil?

            refusal = (attached_insee_code == form.insee_code) ? :already_attached : :siret_already_attached
            (context.refusals ||= []) << refusal
          end

          private

          def form = context.form
        end
      end
    end
  end
end
