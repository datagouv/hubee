# frozen_string_literal: true

module Portail
  # L'historique d'une démarche : la frise groupée par mois et la phrase de chaque event.
  # Le socle des champs (replis, libellés d'état) vit dans DeliveriesHelper, inclus ici.
  module DeliveryEventsHelper
    include Portail::DeliveriesHelper

    # Les events qui ont apporté une pièce. La section « ajoutées ensuite » s'organise par
    # event et non par pièce : c'est la provenance — qui, quand — qui justifie de tenir ces
    # pièces à part de celles du dépôt.
    def delivery_events_with_attachments(delivery)
      delivery.events.select { |event| event.attachments.any? }
    end

    # Du plus RÉCENT au plus ancien, quand la gem trie dans l'autre sens : l'inversion est une
    # décision d'affichage, elle vit donc ici. `group_by` conserve l'ordre d'arrivée, inverser
    # les events suffit à faire sortir les mois dans le même ordre.
    #
    # Les events sans date restent en QUEUE, hors de l'inversion : les faire remonter en tête
    # au seul motif qu'on renverse la liste les présenterait comme les plus récents.
    def delivery_events_by_month(delivery)
      dated, undated = delivery.events.partition(&:created_at)

      (dated.reverse + undated).group_by { |event| event.created_at&.beginning_of_month }
    end

    # Capitalisé : le français écrit les mois en minuscule, mais cette étiquette est un titre
    # de groupe, pas une date dans une phrase.
    def delivery_event_month(month)
      return t("portail.deliveries.events.undated_month") if month.nil?

      l(month, format: :month).capitalize
    end

    # Une phrase et non une étiquette : « X a déposé une pièce » se lit d'un trait. Le type
    # seul ne suffit pas à la choisir — deux téléchargements ne se distinguent que par leur
    # metadata, et un message diffusé n'est pas un commentaire interne.
    #
    # Clés en `_html` : l'auteur vient de l'amont, `tag.strong` l'échappe et l'interpolation
    # d'une clé `_html` échappe tout ce qui n'est pas déjà sûr.
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
        # Même repli que les états : une ligne datée sans phrase vaut mieux qu'une page qui
        # tombe faute d'un type d'event que l'amont a ajouté sans nous prévenir.
        t("portail.deliveries.events.#{event.event_type.tr(".", "_")}_html", author: author,
          default: t("portail.deliveries.events.unknown_html", author: author))
      end
    end

    # Ce que l'amont dit d'un message SORTI du hub. `== false` et non `!`: la metadata ne
    # porte `internal` que sur les messages, et une clé absente ne veut pas dire « diffusé »
    # — un changement d'état n'a rien promis à personne.
    def delivery_event_broadcast?(event) = event.metadata[:internal] == false

    # Le jour de la semaine situe l'événement quand on relit une instruction étalée sur
    # plusieurs jours.
    def delivery_event_time(event)
      return MISSING if event.created_at.nil?

      l(event.created_at, format: :timeline).capitalize
    end
  end
end
