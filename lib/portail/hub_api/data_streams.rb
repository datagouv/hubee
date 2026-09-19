# frozen_string_literal: true

# La gem vit dans un groupe hors `default` : Bundler ne l'auto-requiert pas.
require "hub_api_v1"

module Portail
  module HubAPI
    # Cette lecture ne porte aucune dimension d'organisation : le cloisonnement est celui de
    # l'appelant. On ne passe ici que le code d'un télédossier déjà servi à l'agent.
    module DataStreams
      class << self
        def find(code:, client: HubApiV1.client)
          profile_from(HubApiV1::V2::DataStreamProfile.find(code: code, client: client))
        rescue HubApiV1::Error => e
          raise HubAPI.translated(e)
        end

        private

        # Symbols en amont, String dans le portail : la conversion vit ici seulement, comme pour
        # l'état d'un télédossier.
        def profile_from(profile)
          Portail::DataStream::Profile.new(
            code: profile.code,
            name: profile.name,
            awaiting_documents: profile.awaiting_documents.to_s
          )
        end
      end
    end
  end
end
