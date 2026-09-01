# frozen_string_literal: true

module Portail
  # Ce qu'une démarche présente à l'écran — les CHAMPS : état, dates, demandeur, pièces. Une
  # méthode par champ, qui porte son repli : laissés aux gabarits, ces replis deviennent des
  # ternaires recopiés dont le prochain écran en oubliera un. Une seule fonction sert la liste
  # et le détail, rien ne peut diverger entre les deux.
  #
  # Un helper et non un mixin sur les modèles : un modèle AR dans `::` ne peut pas porter de
  # présentation propre à ::Portail, et un helper est indifférent au type qu'on lui passe — il
  # tiendra pendant la bascule vers ::Delivery ActiveRecord.
  #
  # L'historique vit dans DeliveryEventsHelper, la navigation dans DeliveryNavigationHelper —
  # tous deux incluent ce module, qui porte le socle commun.
  module DeliveriesHelper
    # Ce qu'on écrit là où l'amont n'a rien à dire. Un tiret cadratin, pas un vide : une cellule
    # blanche se lit comme une colonne cassée.
    MISSING = "—"

    # `default:` : la liste des états appartient à l'amont, qui peut en ajouter un sans nous
    # prévenir — sans repli, l'agent lirait « translation missing » dans le tableau.
    #
    # Le libellé est porté par l'ÉTAT et non par la démarche : le menu de navigation n'a que
    # les clés des compteurs, sans démarche sous la main.
    def delivery_state_label(state) = t("portail.deliveries.states.#{state}", default: MISSING)

    def delivery_state(delivery) = delivery_state_label(delivery.state)

    # Les couleurs DSFR par état. Table fermée, repli NEUTRE et non une erreur : faire tomber
    # le détail entier faute d'une couleur serait hors de proportion. `closed` est neutre à
    # dessein — une démarche clôturée n'est ni un succès ni un échec.
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

    def delivery_state_badge(delivery)
      tag.p(delivery_state(delivery),
        class: ["fr-badge", STATE_BADGES[delivery.state]].compact)
    end

    def delivery_transmitted_at(delivery) = delivery_time(delivery.transmitted_at)

    def delivery_updated_at(delivery) = delivery_time(delivery.updated_at)

    # La ligne s'affiche toujours, avec son repli : la masquer ferait disparaître une
    # information sans dire qu'elle manque.
    def delivery_applicant(delivery) = delivery.applicant&.full_name.presence || MISSING

    # Les états DSFR d'une pièce, même politique que ceux d'une démarche : table fermée,
    # repli neutre. `deleted` n'est pas une erreur — la pièce a été retirée, pas refusée.
    ATTACHMENT_BADGES = {
      "pending" => "fr-badge--info",
      "received" => "fr-badge--success",
      "corrupted" => "fr-badge--error",
      "rejected" => "fr-badge--error",
      "deleted" => nil
    }.freeze

    def delivery_attachment_state(attachment)
      tag.p(t("portail.deliveries.attachment_states.#{attachment.state}", default: MISSING),
        class: ["fr-badge", "fr-badge--sm", ATTACHMENT_BADGES[attachment.state]].compact)
    end

    # La taille est DÉCLARATIVE tant que la pièce n'est pas reçue : l'amont ne la contrôle
    # contre le binaire qu'à l'ingestion. Approximative vaut mieux qu'absente pour juger d'un
    # dossier.
    def delivery_attachment_size(attachment)
      return MISSING if attachment.byte_size.blank?

      number_to_human_size(attachment.byte_size)
    end

    private

    # Format long : le jour de la semaine et l'année situent une transmission qu'on relit
    # plusieurs semaines après.
    def delivery_time(value) = value ? l(value, format: :long) : MISSING
  end
end
