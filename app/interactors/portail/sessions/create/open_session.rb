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

          # Émis après l'écriture, contrairement au refus : un accès n'est un fait qu'une
          # fois la session ouverte.
          Rails.event.notify(Portail::Auth::Decision.new(
            outcome: :granted,
            email: context.agent.email,
            provider_sub: context.claims[:sub],
            siret: context.siret,
            acr: context.claims[:acr],
            amr: context.claims[:amr],
            agent_id: context.agent.id,
            membership_id: context.membership.id,
            provider_sub_changed: context.provider_sub_changed
          ))
        end
      end
    end
  end
end
