# frozen_string_literal: true

module Portail
  # Ce qu'une démarche présente à l'écran — les CHAMPS : état, dates, demandeur, pièces. Les
  # champs arrivent de l'amont incomplets — une date jamais renseignée, un demandeur absent du
  # paquet — et le portail les traite tous pareil : une méthode par champ, qui porte son repli.
  # Laissés aux gabarits, ces replis deviennent des ternaires recopiés, et le prochain écran en
  # oubliera un.
  #
  # Un helper et non un mixin sur les modèles : à terme la démarche sera un ::Delivery
  # ActiveRecord, et un modèle AR dans `::` ne peut pas porter de présentation propre à
  # ::Portail. Un helper est indifférent au type qu'on lui passe — il fonctionne sur les Data
  # d'aujourd'hui, sur l'AR de demain, et sur les deux pendant la bascule.
  #
  # C'est aussi ce qui garde la forme liste et la forme détail en parité : une seule fonction
  # sert les deux, il n'y a plus rien qui puisse diverger.
  #
  # L'historique vit dans DeliveryEventsHelper, la navigation (menu d'états, pagination) dans
  # DeliveryNavigationHelper — tous deux incluent ce module, qui porte le socle commun.
  module DeliveriesHelper
    # Ce qu'on écrit là où l'amont n'a rien à dire. Un tiret cadratin, pas un vide : une cellule
    # blanche se lit comme une colonne cassée.
    MISSING = "—"

    # `default:` et non un libellé obligatoire : la liste des états appartient à l'amont, qui
    # peut en ajouter un sans nous prévenir. Sans repli, l'agent lirait « translation missing »
    # en clair dans le tableau.
    #
    # Deux entrées, une seule connaissance : le menu de navigation traduit un état SANS
    # démarche sous la main — il n'a que les clés des compteurs. Faire porter le libellé par
    # l'état, et non par la démarche, est ce qui garde le tableau et le menu d'accord.
    def delivery_state_label(state) = t("portail.deliveries.states.#{state}", default: MISSING)

    def delivery_state(delivery) = delivery_state_label(delivery.state)

    # Les couleurs DSFR par état. Table fermée sur ce qu'on connaît, repli NEUTRE et non une
    # erreur : l'amont peut ajouter un état sans nous prévenir, et faire tomber le détail
    # entier faute d'une couleur serait hors de proportion. `closed` est volontairement neutre
    # — une démarche clôturée n'est ni un succès ni un échec.
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

    # Le demandeur suit la même règle que les dates : la ligne s'affiche toujours, avec son
    # repli quand l'amont n'en sert pas. La masquer ferait disparaître une information sans
    # dire qu'elle manque.
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

    # La taille est DÉCLARATIVE tant que la pièce n'est pas reçue — l'amont ne la contrôle
    # contre le binaire qu'à l'ingestion. On l'affiche quand même : approximative vaut mieux
    # qu'absente pour juger d'un dossier. Elle peut manquer, d'où le repli commun.
    def delivery_attachment_size(attachment)
      return MISSING if attachment.byte_size.blank?

      number_to_human_size(attachment.byte_size)
    end

    private

    # Format long, et non abrégé : « jeudi 20 août 2026 14h30 » se lit sans effort, là où
    # « 20 août 14h30 » oblige à deviner l'année et perd le jour de la semaine — celui-là même
    # qui situe une transmission quand on relit un dossier plusieurs semaines après.
    def delivery_time(value) = value ? l(value, format: :long) : MISSING
  end
end
