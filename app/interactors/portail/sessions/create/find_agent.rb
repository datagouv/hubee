# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      class FindAgent
        include Interactor

        # Une connexion ProConnect ne crée JAMAIS de compte : agent inconnu → échec,
        # aucune écriture. Reconnaissance par provider_sub (stable même si l'email change).
        def call
          agent = Agent.find_by(provider_sub: context.claims[:sub])
          context.fail!(error: :unknown_agent) if agent.nil?

          agent.update!(
            email: context.info[:email],
            first_name: context.info[:first_name],
            last_name: context.info[:last_name],
            amr: context.claims[:amr]
          )
          context.agent = agent
        end
      end
    end
  end
end
