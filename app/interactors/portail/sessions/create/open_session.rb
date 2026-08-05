# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      # L'accès est accordé : la session s'ouvre. Le contrôleur n'a plus qu'à ranger
      # l'identifiant dans le cookie — la session HTTP ne descend pas jusqu'ici.
      class OpenSession
        include Interactor

        def call
          context.provider_session = ProviderSession.create!(
            membership: context.membership,
            provider_id_token: context.id_token,
            email: context.agent.email,
            amr: context.claims[:amr],
            acr: context.claims[:acr]
          )
        end
      end
    end
  end
end
