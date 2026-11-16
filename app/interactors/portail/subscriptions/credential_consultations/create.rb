# frozen_string_literal: true

module Portail
  module Subscriptions
    module CredentialConsultations
      # La consultation des identifiants d'un abonnement API déjà autorisé : la lecture, puis sa trace.
      # La trace suit la lecture : un échec de lecture n'a rien montré, donc rien à tracer.
      class Create
        include Interactor::Organizer

        organize Create::FetchCredentials,
          Create::RecordConsultation
      end
    end
  end
end
