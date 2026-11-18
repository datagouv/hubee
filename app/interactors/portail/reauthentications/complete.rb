# frozen_string_literal: true

module Portail
  module Reauthentications
    # Conclut une réauthentification au retour de ProConnect : le même jugement qu'une connexion,
    # puis la preuve que c'est bien le rattachement de la session qui s'est réauthentifié.
    #
    # Appelé par SessionsController#create, et non par ReauthenticationsController : ProConnect ne
    # connaît qu'une adresse de retour, commune à la connexion et à la réauthentification. D'où
    # `Complete` plutôt que `Create`, que la convention rattacherait à ReauthenticationsController#create,
    # qui ne fait que lancer le parcours.
    class Complete
      include Interactor::Organizer

      # AdoptIdToken écrit avant le second facteur, à dessein : dès que ProConnect a authentifié le
      # rattachement de la session, la session ProConnect ouverte est la sienne, et « Se déconnecter »
      # doit pouvoir la fermer même si la réauthentification est refusée ensuite.
      organize Shared::ExchangeCode, Shared::VerifyIdToken, Shared::CheckAuthenticationLevel,
        Shared::FindAgent, Shared::FindMembership, Complete::CheckSameMembership, Complete::CheckLoggedOut,
        Complete::AdoptIdToken, Shared::CheckSecondFactor, Complete::RecordProof
    end
  end
end
