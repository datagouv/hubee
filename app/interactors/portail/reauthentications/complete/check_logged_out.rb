# frozen_string_literal: true

module Portail
  module Reauthentications
    class Complete
      # Le portail ne voit pas la déconnexion ProConnect : il redirige le navigateur, qui peut ne pas
      # suivre. ProConnect, lui, ouvre une nouvelle session après une déconnexion, avec un nouveau
      # `sid`. Le même `sid` qu'avant prouve que la connexion a réutilisé la session déjà ouverte,
      # sans aucune saisie. Sans `sid`, rien n'est prouvé : refusé plutôt que supposé.
      class CheckLoggedOut
        include Interactor

        def call
          sid = context.claims[:sid]
          return if sid.present? && sid != context.provider_session.provider_sid

          context.fail!(error: :reauthentication_without_logout)
        end
      end
    end
  end
end
