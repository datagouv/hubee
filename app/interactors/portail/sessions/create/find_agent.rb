# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      # Résout l'agent sans rien écrire — la fiche n'est alignée qu'une fois l'accès
      # accordé, par SyncAgentIdentity. Une connexion ne crée JAMAIS de compte.
      class FindAgent
        include Interactor

        def call
          # Normalisée comme à l'écriture : sinon une différence de casse suffirait à
          # faire échouer la recherche puis la comparaison.
          email = Agent.normalize_value_for(:email, context.info.email)

          # Le `sub` identifie l'agent une fois rattaché ; l'adresse ne sert qu'au tout
          # premier rattachement, celui d'un agent enrôlé jamais connecté.
          agent = Agent.find_by(provider_sub: context.claims[:sub]) || Agent.find_by(email:)
          context.fail!(error: :unknown_agent) if agent.nil?

          # Rare : changer d'adresse s'accompagne le plus souvent d'un nouveau compte,
          # donc d'un nouveau `sub`. On bloque par prudence.
          context.fail!(error: :email_mismatch) if agent.email != email

          context.agent = agent
        end
      end
    end
  end
end
