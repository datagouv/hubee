# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      class FindAgent
        include Interactor

        # Une connexion ProConnect ne crée JAMAIS de compte : agent inconnu → échec,
        # aucune écriture.
        def call
          email = context.info[:email]
          sub = context.claims[:sub]

          # Le `sub` identifie l'agent une fois rattaché. L'adresse ne sert qu'au tout
          # premier rattachement — agent enrôlé jamais connecté — et vient du jeton
          # vérifié : la connaître ne suffit pas.
          agent = Agent.find_by(provider_sub: sub) || Agent.find_by(email:)
          context.fail!(error: :unknown_agent) if agent.nil?

          # Rare ici : avec une organisation vérifiée, un changement d'adresse s'accompagne
          # le plus souvent d'un nouveau compte, donc d'un nouveau `sub` — on atterrirait
          # sur « inconnu ». Prévalence réelle incertaine : on bloque et on trace, quitte
          # à réévaluer.
          context.fail!(error: :email_mismatch) if agent.email != email

          agent.update!(
            provider_sub: sub,
            email:,
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
