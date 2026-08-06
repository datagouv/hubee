# frozen_string_literal: true

module Portail
  module Sessions
    class Deny
      # ProConnect a bien identifié l'agent, le portail lui refuse l'entrée. On garde de
      # quoi le lui expliquer, et de quoi lui proposer de changer de compte.
      class RecordRefusal
        include Interactor

        def call
          # Émis avant l'écriture : un refus sans adresse fait échouer la ligne de session,
          # mais la décision a bien été prise et doit rester retrouvable.
          Rails.event.notify(Portail::Auth::Decision.new(
            outcome: :denied,
            reason: context.reason,
            email: context.email,
            provider_sub: context.claims[:sub],
            siret: context.siret,
            organization_label: context.organization_label,
            acr: context.claims[:acr],
            amr: context.claims[:amr],
            agent_id: context.agent_id
          ))

          context.provider_session = ProviderSession.create!(
            denial_reason: context.reason.to_s,
            provider_id_token: context.id_token,
            email: context.email,
            organization_label: context.organization_label,
            amr: context.claims[:amr],
            acr: context.claims[:acr]
          )
        rescue ActiveRecord::RecordInvalid
          # Sans adresse, la page de refus n'aurait rien à montrer.
          context.fail!(error: :incomplete_identity)
        end
      end
    end
  end
end
