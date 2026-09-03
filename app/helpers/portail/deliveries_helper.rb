# frozen_string_literal: true

module Portail
  # Les champs d'une démarche à l'écran, une méthode par champ avec son repli : une seule
  # fonction sert la liste et le détail. Un helper et non un mixin : il est indifférent au
  # type reçu. L'historique et la navigation ont leur propre helper, qui incluent celui-ci.
  module DeliveriesHelper
    # Un tiret et non un vide : une cellule blanche se lit comme une colonne cassée.
    MISSING = "—"

    # Table fermée, repli neutre : un état inconnu ne fait pas tomber le détail. `closed` est
    # neutre à dessein, une démarche clôturée n'est ni un succès ni un échec.
    STATE_BADGES = {
      "transmitted" => "fr-badge--new",
      "acknowledged" => "fr-badge--info",
      "in_progress" => "fr-badge--info",
      "awaiting_documents" => "fr-badge--warning",
      "done" => "fr-badge--success",
      "refused" => "fr-badge--error",
      "closed" => nil,
      "integration_error" => "fr-badge--error"
    }.freeze

    # Même politique. `deleted` n'est pas une erreur : la pièce a été retirée, pas refusée.
    ATTACHMENT_BADGES = {
      "pending" => "fr-badge--info",
      "received" => "fr-badge--success",
      "corrupted" => "fr-badge--error",
      "rejected" => "fr-badge--error",
      "deleted" => nil
    }.freeze

    # `default:` : l'amont peut ajouter un état sans nous prévenir. Porté par l'état et non
    # par la démarche : le menu n'a que les clés des compteurs.
    def delivery_state_label(state) = t("portail.deliveries.states.#{state}", default: MISSING)

    def delivery_state(delivery) = delivery_state_label(delivery.state)

    def delivery_state_badge(delivery)
      tag.p(delivery_state(delivery),
        class: ["fr-badge", STATE_BADGES[delivery.state]].compact)
    end

    def delivery_transmitted_at(delivery) = delivery_time(delivery.transmitted_at)

    def delivery_updated_at(delivery) = delivery_time(delivery.updated_at)

    # Toujours affiché, avec son repli : masquer la ligne cacherait que l'information manque.
    def delivery_applicant(delivery) = delivery.applicant&.full_name.presence || MISSING

    def delivery_attachment_state(attachment)
      tag.p(t("portail.deliveries.attachment_states.#{attachment.state}", default: MISSING),
        class: ["fr-badge", "fr-badge--sm", ATTACHMENT_BADGES[attachment.state]].compact)
    end

    # Déclarative tant que la pièce n'est pas reçue : approximative vaut mieux qu'absente.
    def delivery_attachment_size(attachment)
      return MISSING if attachment.byte_size.blank?

      number_to_human_size(attachment.byte_size)
    end

    private

    # Format long : le jour et l'année situent une transmission relue des semaines après.
    def delivery_time(value) = value ? l(value, format: :long) : MISSING
  end
end
