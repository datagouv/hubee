# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      # Le niveau est lu dans le jeton vérifié, jamais ailleurs : ce qui a été demandé au
      # départ ne prouve rien de ce qui a été atteint. Ce que le portail accepte, et
      # pourquoi le plancher est là, sont décrits par Portail::AuthenticationLevels.
      class CheckAuthenticationLevel
        include Interactor

        def call
          return if Portail::AuthenticationLevels.accepted?(context.claims[:acr])

          context.fail!(error: :insufficient_authentication_level)
        end
      end
    end
  end
end
