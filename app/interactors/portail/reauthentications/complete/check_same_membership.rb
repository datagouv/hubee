# frozen_string_literal: true

module Portail
  module Reauthentications
    class Complete
      # L'agent est résolu comme à la connexion, par `sub` sinon par adresse, et le rattachement par
      # le SIRET : c'est ce rattachement, et aucun autre, qui doit être celui de la session.
      class CheckSameMembership
        include Interactor

        def call
          return if context.membership == context.provider_session.membership

          context.fail!(error: :reauthentication_mismatch)
        end
      end
    end
  end
end
