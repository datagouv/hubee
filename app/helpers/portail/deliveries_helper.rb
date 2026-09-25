# frozen_string_literal: true

module Portail
  # Les champs d'un télédossier à l'écran, une méthode par champ avec son repli : une seule
  # fonction sert la liste et le détail. Un helper et non un mixin : il est indifférent au
  # type reçu. L'historique et la navigation ont leur propre helper, qui incluent celui-ci.
  module DeliveriesHelper
    # Un tiret et non un vide : une cellule blanche se lit comme une colonne cassée.
    MISSING = "—"

    # Table fermée, repli neutre : un état inconnu ne fait pas tomber le détail. `closed` est
    # neutre à dessein, un télédossier clos n'est ni un succès ni un échec.
    STATE_BADGES = {
      "transmitted" => "fr-badge--new",
      "acknowledged" => "fr-badge--info",
      "in_progress" => "fr-badge--info",
      "awaiting_attachments" => "fr-badge--warning",
      "done" => "fr-badge--success",
      "refused" => "fr-badge--error",
      "closed" => nil
    }.freeze

    # Même politique. `deleted` n'est pas une erreur : la pièce a été retirée, pas refusée.
    ATTACHMENT_BADGES = {
      "pending" => "fr-badge--info",
      "received" => "fr-badge--success",
      "corrupted" => "fr-badge--error",
      "rejected" => "fr-badge--error",
      "deleted" => nil
    }.freeze

    # `default:` : l'amont peut ajouter un état sans nous prévenir. `blank?` à part : I18n
    # résoudrait la clé tronquée vers son parent, le Hash entier des libellés.
    def delivery_state_label(state)
      return MISSING if state.blank?

      t("portail.deliveries.states.#{state}", default: MISSING)
    end

    def delivery_state(delivery) = delivery_state_label(delivery.state)

    def delivery_offered_states(delivery, data_stream)
      Access::StateTransitions.offered_from(delivery.state, data_stream)
    end

    def delivery_receipt_offered?(delivery, data_stream)
      delivery_offered_states(delivery, data_stream).include?(delivery_receipt_state)
    end

    def delivery_receipt_state = Access::StateTransitions::RECEIPT

    def delivery_state_badge(delivery)
      tag.p(delivery_state(delivery),
        class: ["fr-badge", STATE_BADGES[delivery.state]].compact)
    end

    def delivery_transmitted_at(delivery) = delivery_time(delivery.transmitted_at)

    def delivery_updated_at(delivery) = delivery_time(delivery.updated_at)

    # Le code reste, après un tiret : c'est lui qui sert au support. Sans nom, le code seul, jamais
    # une ligne vide ni une page en moins.
    def data_stream_label(code, name)
      name ? "#{name} – #{code}" : code
    end

    # Toujours affiché, avec son repli : masquer la ligne cacherait que l'information manque.
    def delivery_applicant(delivery) = delivery.applicant&.full_name.presence || MISSING

    def delivery_attachment_state(attachment)
      tag.p(t("portail.deliveries.attachment_states.#{attachment.state}", default: MISSING),
        class: ["fr-badge", "fr-badge--sm", ATTACHMENT_BADGES[attachment.state]].compact)
    end

    def delivery_attachment_name(attachment)
      attachment.filename.presence || Delivery::Attachment::FALLBACK_FILENAME
    end

    # Le lien quand la pièce se remet, sinon son état, qui est la raison. Sans télédossier, la
    # pièce est celle d'un événement : elle n'a pas d'adresse.
    # RGAA : le nom accessible porte la pièce, un même intitulé par ligne ne suffisant pas. Le nom
    # du fichier vient après le texte visible, que le nom accessible doit contenir d'un bloc.
    def delivery_attachment_access(attachment, delivery)
      return delivery_attachment_state(attachment) unless delivery && attachment.state_received?

      link_to teledossier_piece_path(delivery.id, attachment.id),
        class: "fr-link fr-link--download",
        # Surtout pas `download` : il enregistrerait la réponse quelle qu'elle soit, page d'erreur
        # comprise. `turbo: false` : Turbo ne sait pas suivre une réponse qui n'est pas du HTML.
        data: {turbo: false} do
        safe_join([t("portail.deliveries.attachments.download"),
          tag.span(", #{delivery_attachment_name(attachment)}", class: "fr-sr-only")])
      end
    end

    # L'archive ne remet que les pièces reçues : l'agent sait avant le clic combien, et sur quel
    # total, les autres restant lisibles dans le tableau avec leur état. Rien sans pièce reçue.
    # Le détail tait la taille : on connaît la somme de celles des pièces, pas la taille compressée.
    def delivery_archive_access(delivery)
      received = delivery.received_attachments.size
      return if received.zero?

      total = delivery.attachments.size
      complete = received == total
      label = if complete
        t("portail.deliveries.archives.download.complete", count: received)
      else
        t("portail.deliveries.archives.download.partial", count: received, total:)
      end
      render "portail/deliveries/archive_access", delivery:, label:, complete:
    end

    # Déclarative tant que la pièce n'est pas reçue : approximative vaut mieux qu'absente.
    def delivery_attachment_size(attachment)
      return MISSING if attachment.byte_size.blank?

      number_to_human_size(attachment.byte_size)
    end

    # Rendu sur le seul chemin réussi : la frontière a déjà refusé toute date illisible.
    def delivery_period_label(criteria)
      from = criteria.transmitted_from && l(Date.iso8601(criteria.transmitted_from))
      to = criteria.transmitted_to && l(Date.iso8601(criteria.transmitted_to))
      if from && to
        t("portail.deliveries.active_filters.between", from: from, to: to)
      elsif from
        t("portail.deliveries.active_filters.from", from: from)
      else
        t("portail.deliveries.active_filters.to", to: to)
      end
    end

    private

    # Format long : le jour et l'année situent une transmission relue des semaines après.
    def delivery_time(value) = value ? l(value, format: :long) : MISSING
  end
end
