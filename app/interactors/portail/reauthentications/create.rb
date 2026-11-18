# frozen_string_literal: true

module Portail
  module Reauthentications
    # Conclut une réauthentification au retour de ProConnect : le même jugement qu'une connexion,
    # puis la preuve que c'est bien le rattachement de la session qui s'est réauthentifié.
    class Create
      include Interactor::Organizer

      # AdoptIdToken écrit avant le second facteur, à dessein : dès que ProConnect a authentifié le
      # rattachement de la session, la session ProConnect ouverte est la sienne, et « Se déconnecter »
      # doit pouvoir la fermer même si la réauthentification est refusée ensuite.
      organize Shared::ExchangeCode, Shared::VerifyIdToken, Shared::CheckAuthenticationLevel,
        Shared::FindAgent, Shared::FindMembership, Create::CheckSameMembership, Create::CheckLoggedOut,
        Create::AdoptIdToken,
        Shared::CheckSecondFactor, Create::RecordProof
    end
  end
end
