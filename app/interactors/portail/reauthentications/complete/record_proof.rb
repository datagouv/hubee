# frozen_string_literal: true

module Portail
  module Reauthentications
    class Complete
      class RecordProof
        include Interactor

        def call
          Access::Reauthentication.record!(context.provider_session, purpose: context.purpose,
            id_token: context.id_token, acr: context.claims[:acr], amr: context.claims[:amr])

          # Émis après l'écriture, comme une connexion accordée : la preuve n'est un fait qu'une fois
          # posée.
          Rails.event.notify(Portail::Auth::Decision.new(
            outcome: :granted,
            kind: :reauthentication,
            email: context.agent.email,
            provider_sub: context.claims[:sub],
            siret: context.siret,
            organization_label: context.organization_label,
            idp_id: context.idp_id,
            acr: context.claims[:acr],
            amr: context.claims[:amr],
            agent_id: context.agent.id,
            membership_id: context.membership.id
          ))
        end
      end
    end
  end
end
