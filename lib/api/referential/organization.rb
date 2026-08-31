# frozen_string_literal: true

# La gem n'est pas auto-requise : elle vit dans un groupe Bundler hors `default`,
# que Bundler.require ne charge pas.
require "hub_api_v1"

module API
  module Referential
    # Traduit le référentiel V1 dans le vocabulaire V2 : au-delà de ce fichier, personne ne
    # connaît le triplet V1 ni ne décide — ce que la classe rend ou lève reste un constat.
    class Organization
      # Le référentiel a répondu, et ne connaît pas ce couple. Constat, pas verdict :
      # l'appelant décide si ça vaut un refus ou un repli.
      class NotFound < StandardError; end

      # Le référentiel n'a pas répondu.
      class Unavailable < StandardError; end

      # Le référentiel a répondu, mais plusieurs organisations partagent un triplet qui est sa
      # clé primaire : réessayer rendra le même doublon tant que la donnée n'est pas corrigée.
      class Inconsistent < StandardError; end

      # Type sous lequel on interroge le référentiel, posé ici et non en paramètre : un
      # appelant ne peut ainsi jamais présenter le mauvais type.
      TYPE = "SI"

      Record = Data.define(:siret, :insee_code, :name)

      class << self
        def find(siret:, insee_code:)
          record = HubApiV1::Organization.find(siret: siret, type: TYPE, branch_code: insee_code)

          Record.new(siret: record.siret, insee_code: record.branch_code, name: record.name)
        rescue HubApiV1::OrganizationNotFoundError
          raise NotFound, "Aucune organisation #{TYPE} pour le SIRET #{siret} et le code guichet #{insee_code}"
        rescue HubApiV1::AmbiguousOrganizationError
          raise Inconsistent, "Plusieurs organisations #{TYPE} pour le SIRET #{siret} et le code guichet #{insee_code}"
        rescue HubApiV1::Client::Error
          raise Unavailable, "Le référentiel des organisations n'a pas répondu"
        end
      end
    end
  end
end
