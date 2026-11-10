# frozen_string_literal: true

module Portail
  module Subscriptions
    module Credentials
      class Create
        # La trace d'audit de la consultation. L'agent et son organisation sont recopiés dans les
        # métadonnées : la trace doit encore dire qui a consulté, et pour quelle organisation, une fois
        # l'agent ou son rattachement supprimé. Le secret n'y figure jamais.
        class RecordConsultation
          include Interactor

          def call
            Event.create!(
              eventable: membership,
              event_type: "subscription.credentials_revealed",
              metadata: {
                subscription_id: context.subscription.id,
                data_stream_code: context.subscription.data_stream_code,
                agent_id: membership.agent_id,
                email: membership.agent.email,
                siret: membership.organization_link.siret,
                insee_code: membership.organization_link.insee_code
              }
            )
          rescue ActiveRecord::ActiveRecordError => e
            # Pas de trace, pas d'affichage : les identifiants lus quittent le contexte.
            Rails.error.report(e, handled: true)
            context.credentials = nil
            context.fail!(error: :unavailable)
          end

          private

          def membership = context.membership
        end
      end
    end
  end
end
