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
      "awaiting_documents" => "fr-badge--warning",
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

    # Même forme qu'en liste. Le profil est lu une fois par le controller : la vue ne déclenche
    # aucune lecture amont et n'interprète aucun échec.
    def delivery_data_stream_label(delivery, profile)
      code = delivery.data_stream.code
      data_stream_label(code, {code => profile&.name}.compact)
    end

    def delivery_offered_states(delivery, profile)
      Access::StateTransitions.offered_from(delivery.state, profile)
    end

    def delivery_state_badge(delivery)
      tag.p(delivery_state(delivery),
        class: ["fr-badge", STATE_BADGES[delivery.state]].compact)
    end

    def delivery_transmitted_at(delivery) = delivery_time(delivery.transmitted_at)

    def delivery_updated_at(delivery) = delivery_time(delivery.updated_at)

    # Le code reste, après un tiret : c'est lui qui sert au support. Sans libellé, le code seul,
    # jamais une ligne vide ni une page en moins.
    def data_stream_label(code, names)
      name = names[code]
      name ? "#{name} – #{code}" : code
    end

    # Toujours affiché, avec son repli : masquer la ligne cacherait que l'information manque.
    def delivery_applicant(delivery) = delivery.applicant&.full_name.presence || MISSING

    def delivery_attachment_state(attachment)
      tag.p(t("portail.deliveries.attachment_states.#{attachment.state}", default: MISSING),
        class: ["fr-badge", "fr-badge--sm", ATTACHMENT_BADGES[attachment.state]].compact)
    end

    # Le bouton quand la pièce se remet, sinon son état, qui est la raison. Sans télédossier, la
    # pièce est celle d'un événement : elle n'a pas d'adresse.
    # `download` : le navigateur reçoit le fichier lui-même, Turbo n'intercepte pas. Le nom
    # accessible porte la pièce : un même intitulé par ligne ne suffit pas au RGAA.
    def delivery_attachment_access(attachment, delivery)
      return delivery_attachment_state(attachment) unless delivery && attachment.state_received?

      link_to t("portail.deliveries.attachments.download"),
        teledossier_piece_path(delivery.id, attachment.id),
        class: "fr-btn fr-btn--sm fr-btn--secondary fr-icon-download-line fr-btn--icon-left",
        aria: {label: t("portail.deliveries.attachments.download_named", filename: attachment.filename)},
        download: true
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
