# frozen_string_literal: true

# La gem vit dans un groupe hors `default` : Bundler ne l'auto-requiert pas.
require "hub_api_v1"

module API
  module HubAPI
    module Organizations
      # Hypothèse : un agent du portail appartient toujours à un SI. Le référentiel ne le garantit pas.
      TYPE = "SI"

      class << self
        def verify(siret:, insee_code:, client: HubApiV1.client)
          # Le code de branche du référentiel est le code INSEE, le code guichet de la V2.
          HubApiV1::Organization.find(siret: siret, type: TYPE, branch_code: insee_code, client: client)
          true
        rescue HubApiV1::Error => e
          raise HubAPI.translated(e)
        end
      end
    end
  end
end
