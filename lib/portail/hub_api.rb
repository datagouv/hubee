# frozen_string_literal: true

module Portail
  # La couche de traduction avec la gem cliente : le portail ne connaît que ses propres modèles
  # et ces erreurs-ci. Seule l'écriture locale d'une archive laisse passer les siennes.
  module HubAPI
    class Error < StandardError; end

    # L'amont n'a pas répondu, ou pas de façon exploitable.
    class Unavailable < Error; end

    # Inexistante ou hors du périmètre interrogé, à dessein confondus : distinguer confirmerait
    # l'existence d'un dossier que l'agent n'a pas à voir.
    class NotFound < Error; end

    # L'amont n'a pas servi le contenu d'une pièce, sans dire pourquoi : binaire absent ou panne de
    # la route. Ni une absence, ni une panne — l'une ferait nier une pièce peut-être intacte,
    # l'autre promettrait un réessai qui n'aboutira peut-être jamais.
    class ContentUnavailable < Error; end

    # Paramètre refusé avant tout aller-retour réseau, typiquement un état ou une page trafiqués.
    # Montré à l'agent plutôt que corrigé en silence.
    class InvalidRequest < Error; end

    # Le flux n'autorise pas l'attente de compléments : ni une panne, ni une erreur de l'agent,
    # mais un refus à montrer tel quel.
    class AwaitingAttachmentsNotAllowed < Error; end

    # Refus DÉFINITIF sur ce télédossier : aucun réessai n'y changera quoi que ce soit, et le dire
    # à l'agent lui épargne d'insister.
    class EventLimitReached < Error; end

    class << self
      # La classe d'origine reste dans le message : c'est elle qui distingue une panne d'un refus
      # au journal. Les deux familles de refus : le client V1 et sa surcouche V2 ont chacun le leur.
      def translated(error)
        case error
        when HubApiV1::V2::DeliveryNotFoundError, HubApiV1::V2::AttachmentNotFoundError,
          HubApiV1::V2::DataStreamNotFoundError
          NotFound.new(error.message)
        # Deux refus de l'amont, pas deux incidents : ils ne passent donc pas par le rapporteur.
        when HubApiV1::V2::AwaitingAttachmentsNotAllowedError
          AwaitingAttachmentsNotAllowed.new(error.message)
        when HubApiV1::V2::DeliveryEventLimitReachedError then EventLimitReached.new(error.message)
        when HubApiV1::V2::AttachmentUnavailableError then ContentUnavailable.new(error.message)
        when HubApiV1::InvalidArgumentError, HubApiV1::V2::InvalidArgumentError
          InvalidRequest.new(error.message)
        else
          # Une panne est un incident, signalé ici et non par chaque appelant : un seul point,
          # avec l'exception d'origine. Le portail ne nomme pas Sentry, abonné au rapporteur.
          Rails.error.report(error, handled: true)
          Unavailable.new("#{error.class} : #{error.message}")
        end
      end
    end
  end
end
