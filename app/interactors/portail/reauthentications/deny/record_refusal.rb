# frozen_string_literal: true

module Portail
  module Reauthentications
    class Deny
      # Ce que ProConnect a présenté, et la session dont l'agent demandait la réauthentification : c'est
      # elle que le support et le CSIRT retrouvent. Appelé avant toute fermeture de session.
      class RecordRefusal
        include Interactor

        def call
          return unless context.traced

          claims = context.claims || {}
          Rails.event.notify(Portail::Auth::Decision.new(
            outcome: :denied, kind: :reauthentication, reason: context.reason,
            email: context.email, provider_sub: claims[:sub], siret: context.siret,
            organization_label: context.organization_label, idp_id: context.idp_id,
            acr: claims[:acr], amr: Array(claims[:amr]),
            agent_id: context.provider_session.membership.agent_id,
            membership_id: context.provider_session.membership_id
          ))
        end
      end
    end
  end
end
