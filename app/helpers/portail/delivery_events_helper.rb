# frozen_string_literal: true

module Portail
  # L'historique d'une démarche : la frise groupée par mois et la phrase de chaque event.
  module DeliveryEventsHelper
    include Portail::DeliveriesHelper

    # Par event et non par pièce : c'est la provenance, qui et quand, qui distingue ces pièces
    # de celles du dépôt.
    def delivery_events_with_attachments(delivery)
      delivery.events.select { |event| event.attachments.any? }
    end

    # Du plus récent au plus ancien, trié ici et non confié à l'amont ; à date égale, le rang
    # d'arrivée départage. Les events sans date restent en queue, hors du tri.
    def delivery_events_by_month(delivery)
      dated, undated = delivery.events.partition(&:created_at)
      newest_first = dated.sort_by.with_index { |event, rank| [event.created_at, rank] }.reverse

      (newest_first + undated).group_by { |event| event.created_at&.beginning_of_month }
    end

    # Capitalisé : un titre de groupe, pas une date dans une phrase.
    def delivery_event_month(month)
      return t("portail.deliveries.events.undated_month") if month.nil?

      l(month, format: :month).capitalize
    end

    # Une phrase, choisie par le type et la metadata : deux téléchargements ne se distinguent
    # que par elle. Clés `_html` : `tag.strong` échappe l'auteur, qui vient de l'amont.
    def delivery_event_sentence(event)
      author = tag.strong(event.author.presence || t("portail.deliveries.events.unknown_author"))

      case event.event_type
      when "delivery.state_changed"
        t("portail.deliveries.events.state_changed_html", author: author,
          from: delivery_state_label(event.metadata[:from_state]),
          to: delivery_state_label(event.metadata[:to_state]))
      when "attachment.downloaded"
        t("portail.deliveries.events.#{event.metadata[:bulk] ? "downloaded_all" : "downloaded"}_html",
          author: author)
      when "message.created"
        t("portail.deliveries.events.#{event.metadata[:internal] ? "comment_added" : "message_sent"}_html",
          author: author)
      else
        # Même repli que les états : un type ajouté en amont ne fait pas tomber la page.
        t("portail.deliveries.events.#{event.event_type.tr(".", "_")}_html", author: author,
          default: t("portail.deliveries.events.unknown_html", author: author))
      end
    end

    # `== false` et non `!` : la clé n'existe que sur les messages, absente ne veut pas dire
    # « diffusé ».
    def delivery_event_broadcast?(event) = event.metadata[:internal] == false

    # Le jour de la semaine situe l'événement dans une instruction étalée sur plusieurs jours.
    def delivery_event_time(event)
      return MISSING if event.created_at.nil?

      l(event.created_at, format: :timeline).capitalize
    end
  end
end
