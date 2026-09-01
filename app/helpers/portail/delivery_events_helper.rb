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

    # L'historique se lit par mois, du plus RÉCENT au plus ancien. La gem, elle, trie du plus
    # ancien au plus récent : c'est son contrat, et il ne change pas — l'inversion est une
    # décision d'affichage, elle vit donc ici. Ce qu'un agent vient chercher en ouvrant un
    # historique, c'est ce qui s'est passé en dernier.
    #
    # `group_by` conserve l'ordre d'arrivée : inverser les events suffit à faire sortir les
    # mois dans le même ordre qu'eux, sans trier les clés séparément.
    #
    # Les events sans date restent en QUEUE et ne suivent pas l'inversion : la gem les y range
    # faute de pouvoir les situer, et les faire remonter en tête au seul motif qu'on renverse
    # la liste les présenterait comme les plus récents — ce que personne ne sait. Ils forment
    # un dernier groupe, que le gabarit intitule à part.
    def delivery_events_by_month(delivery)
      dated, undated = delivery.events.partition(&:created_at)

      (dated.reverse + undated).group_by { |event| event.created_at&.beginning_of_month }
    end

    # « Janvier 2026 ». Capitalisé ici : le français écrit les mois en minuscule, mais cette
    # étiquette ouvre un groupe — c'est un titre, pas une date dans une phrase.
    def delivery_event_month(month)
      return t("portail.deliveries.events.undated_month") if month.nil?

      l(month, format: :month).capitalize
    end

    # Ce que dit une ligne d'historique, sous forme de phrase et non d'étiquette : « X a
    # déposé une pièce » se lit d'un trait là où « Pièce déposée » suivi d'un nom oblige à
    # recomposer qui a fait quoi.
    #
    # Le type seul ne suffit pas à choisir la phrase : un téléchargement en masse et un
    # téléchargement unitaire partagent le même type et ne se distinguent que par leur
    # metadata, et un message diffusé n'est pas un commentaire interne.
    #
    # Clés en `_html` : l'auteur vient de l'amont et doit être échappé, ce que `tag.strong`
    # fait, là où l'interpolation d'une clé `_html` échappe tout ce qui n'est pas déjà sûr.
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
        # Même repli que les états : l'amont peut ajouter un type d'event sans nous prévenir,
        # et une ligne d'historique datée sans phrase vaut mieux qu'une page qui tombe.
        t("portail.deliveries.events.#{event.event_type.tr(".", "_")}_html", author: author,
          default: t("portail.deliveries.events.unknown_html", author: author))
      end
    end

    # Ce que l'amont dit d'un message SORTI du hub. `== false` et non `!`: la metadata ne
    # porte `internal` que sur les messages, et une clé absente ne veut pas dire « diffusé »
    # — un changement d'état n'a rien promis à personne.
    def delivery_event_broadcast?(event) = event.metadata[:internal] == false

    # « Samedi 10/01 - 16:16 » : le jour de la semaine situe l'événement bien mieux qu'une
    # date seule quand on relit une instruction étalée sur plusieurs jours.
    def delivery_event_time(event)
      return MISSING if event.created_at.nil?

      l(event.created_at, format: :timeline).capitalize
    end
  end
end
