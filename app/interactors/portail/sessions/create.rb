# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      include Interactor::Organizer

      # Les deux dernières étapes écrivent : rien ne l'est tant que l'accès n'est pas
      # acquis, c'est-à-dire tant que FindMembership n'a pas conclu.
      organize VerifyIdToken, CheckAuthenticationLevel, FindAgent, FindMembership,
        SyncAgentIdentity, OpenSession
    end
  end
end
