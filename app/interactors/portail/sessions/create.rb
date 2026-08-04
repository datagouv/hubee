# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      include Interactor::Organizer

      # SyncAgentIdentity vient en dernier : rien n'est écrit tant que l'accès n'est
      # pas acquis.
      organize VerifyIdToken, CheckAuthenticationLevel, FindAgent, FindMembership,
        SyncAgentIdentity
    end
  end
end
