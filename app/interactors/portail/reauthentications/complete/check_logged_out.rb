# frozen_string_literal: true

module Portail
  module Reauthentications
    class Complete
      # Le portail ne voit pas la déconnexion ProConnect : il redirige le navigateur, qui peut ne pas
      # suivre. ProConnect, lui, ouvre une nouvelle session après une déconnexion, avec un nouveau
      # `sid`. Le même `sid` qu'avant prouve que la connexion a réutilisé la session déjà ouverte,
      # sans aucune saisie. Sans `sid`, rien n'est prouvé : refusé plutôt que supposé.
      #
      # Une session sans `sid` rangé n'a rien à comparer : tout `sid` au retour en différerait. Refusée
      # sous son propre motif, puisque rien n'y dit que la déconnexion a été évitée : l'agent se
      # reconnecte, sans être signalé comme suspect. Une omission de ProConnect à la connexion est
      # signalée au journal (Sessions::Create::OpenSession).
      class CheckLoggedOut
        include Interactor

        def call
          before = context.provider_session.provider_sid
          context.fail!(error: :reauthentication_unprovable) if before.blank?

          sid = context.claims[:sid]
          return if sid.present? && sid != before

          context.fail!(error: :reauthentication_without_logout)
        end
      end
    end
  end
end
