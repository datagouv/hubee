# frozen_string_literal: true

module Portail
  module Subscriptions
    module CredentialConsultations
      class Create
        # La trace d'audit de la consultation, sans identifiant ni secret. L'agent et son
        # organisation sont recopiés : la trace doit rester lisible une fois l'agent ou son
        # rattachement supprimé. Sans rescue, à dessein : pas de trace, pas d'affichage.
        # Les identifiants n'existent pas en base : la trace s'accroche au rattachement de l'acteur,
        # selon la convention de nommage et d'eventable décrite sur Event::TYPES.
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
