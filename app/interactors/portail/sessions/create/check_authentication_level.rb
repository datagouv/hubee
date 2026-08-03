# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      # ProConnect gradue l'authentification sur trois dimensions : la preuve d'identité,
      # la méthode d'authentification, et le lien organisationnel. Au niveau 0 ce dernier
      # est déclaratif — l'agent affirme son organisation sans que personne ne l'atteste —,
      # y compris avec un second facteur. On refuse donc sur le niveau, pas sur l'absence
      # de MFA : `eidas0-mfa` est tout aussi déclaratif que `eidas0`.
      #
      # Le niveau est lu dans le jeton vérifié, jamais ailleurs.
      class CheckAuthenticationLevel
        include Interactor

        ACCEPTED_LEVELS = %w[eidas1 eidas1-mfa eidas2 eidas3].freeze

        def call
          return if ACCEPTED_LEVELS.include?(context.claims[:acr])

          context.fail!(error: :insufficient_authentication_level)
        end
      end
    end
  end
end
