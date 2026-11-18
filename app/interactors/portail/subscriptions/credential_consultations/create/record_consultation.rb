# frozen_string_literal: true

module Portail
  module Subscriptions
    module CredentialConsultations
      class Create
        # La trace, sans identifiant ni secret ; agent et organisation recopiés pour survivre à leur
        # suppression. Sans rescue, à dessein : pas de trace, pas d'affichage. Eventable : Event::TYPES.
        class RecordConsultation
          include Interactor

          def call
            Event.create!(eventable: membership, event_type: "subscription_credentials.consulted", metadata:)
            # Le journal sans donnée personnelle : l'adresse reste dans la table.
            Rails.logger.info("Identifiants d'abonnement consultés",
              subscription_id: subscription.id, membership_id: membership.id, agent_id: membership.agent_id)
          end

          private

          def membership = context.membership

          def subscription = context.subscription

          def metadata
            link = membership.organization_link
            {
              agent_id: membership.agent_id, email: membership.agent.email,
              siret: link.siret, insee_code: link.insee_code,
              subscription_id: subscription.id, data_stream_code: subscription.data_stream_code,
              request_id: context.request_id
            }
          end
        end
      end
    end
  end
end
