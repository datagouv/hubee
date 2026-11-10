# frozen_string_literal: true

module Portail
  module Subscriptions
    module Credentials
      # Les identifiants du client OAuth d'un abonnement déjà autorisé. Lire, puis tracer : une trace
      # sans lecture réussie mentirait, et une lecture sans trace n'est pas montrée.
      class Create
        include Interactor::Organizer

        organize Create::FetchCredentials, Create::RecordConsultation
      end
    end
  end
end
