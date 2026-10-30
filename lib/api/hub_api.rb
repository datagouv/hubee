# frozen_string_literal: true

module API
  # La frontière de l'API avec la gem cliente : aucun type HubApiV1:: n'en sort, seulement ces
  # erreurs-ci, et ArgumentError sur une désignation blanche.
  module HubAPI
    class Error < StandardError; end

    # Réponse définitive : réessayer n'y changera rien.
    class NotFound < Error; end

    # Le référentiel n'a pas répondu de façon fiable : l'appelant peut réessayer.
    class Unavailable < Error; end

    class << self
      # La classe d'origine reste dans le message : c'est elle qui distingue les pannes au journal.
      def translated(error)
        case error
        when HubApiV1::OrganizationNotFoundError then NotFound.new(error.message)
        when HubApiV1::V2::DataStreamNotFoundError then NotFound.new(error.message)
        # Refusée par la gem avant tout appel : un bug d'appelant, que réessayer ne corrigera pas.
        when HubApiV1::InvalidArgumentError then ArgumentError.new(error.message)
        when HubApiV1::V2::InvalidArgumentError then ArgumentError.new(error.message)
        else
          # Une panne est un incident, signalé ici et non par chaque appelant. Le référentiel qui
          # viole sa propre clé (ambiguïté) en est une : jamais tranchée ici.
          Rails.error.report(error, handled: true)
          Unavailable.new("#{error.class} : #{error.message}")
        end
      end
    end
  end
end
