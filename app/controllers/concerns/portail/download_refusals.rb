# frozen_string_literal: true

module Portail
  # Les refus d'un téléchargement sous un télédossier, pièce seule ou archive : mêmes pages, mêmes
  # statuts. Seuls le sujet nommé par la page et l'alerte du compte sans nom changent.
  module DownloadRefusals
    extend ActiveSupport::Concern

    private

    def render_failure(error, subject:, unknown_author_alert:)
      case error
      when :not_found then not_found
      when :event_limit_reached then event_limit_reached(subject)
      when :content_unavailable then content_unavailable(subject)
      when :unknown_author then redirect_to teledossier_path(@delivery.id), alert: t(unknown_author_alert)
      else unavailable
      end
    end

    # 409 et non 503 : l'état de la ressource s'oppose à la demande, aucun réessai n'y changera rien.
    def event_limit_reached(subject)
      render("portail/errors/delivery_event_limit_reached", status: :conflict,
        locals: {delivery_path: teledossier_path(@delivery.id), subject:})
    end

    # 503, faute de savoir : l'amont ne distingue pas une pièce purgée d'un stockage en panne. La
    # page le dit à l'agent au lieu d'annoncer un service qui ne répond pas.
    def content_unavailable(subject)
      render("portail/errors/attachment_content_unavailable", status: :service_unavailable,
        locals: {delivery_path: teledossier_path(@delivery.id), subject:})
    end
  end
end
