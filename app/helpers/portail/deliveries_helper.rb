# frozen_string_literal: true

module Portail
  # Ce qu'une démarche présente à l'écran. Les champs arrivent de l'amont incomplets — une date
  # jamais renseignée, un demandeur absent du paquet — et le portail les traite tous pareil :
  # une méthode par champ, qui porte son repli. Laissés aux gabarits, ces replis deviennent des
  # ternaires recopiés, et le prochain écran en oubliera un.
  #
  # Un helper et non un mixin sur les modèles : à terme la démarche sera un ::Delivery
  # ActiveRecord, et un modèle AR dans `::` ne peut pas porter de présentation propre à
  # ::Portail. Un helper est indifférent au type qu'on lui passe — il fonctionne sur les Data
  # d'aujourd'hui, sur l'AR de demain, et sur les deux pendant la bascule.
  #
  # C'est aussi ce qui garde la forme liste et la forme détail en parité : une seule fonction
  # sert les deux, il n'y a plus rien qui puisse diverger.
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

    # Le lien d'un état dans le menu latéral. DSFR marque l'entrée active par `aria-current`
    # et non par une classe : `aria-current: nil` ne rend aucun attribut, donc un seul chemin
    # ici plutôt qu'une branche par état.
    #
    # Le compteur est un badge et non du texte libre : il reste dans le système, et il est lu
    # par les lecteurs d'écran à la suite du libellé — le masquer priverait de l'information
    # qui fait tout l'intérêt du menu.
    def delivery_state_menu_link(state, count, current:)
      link_to(demarches_path(statut: state), class: "fr-sidemenu__link",
        "aria-current": ("page" if current)) do
        safe_join([
          delivery_state_label(state),
          tag.span(count, class: "fr-badge fr-badge--sm fr-badge--no-icon")
        ], " ")
      end
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

    # Fenêtre de pagination : les deux extrémités, la page courante et ses voisines immédiates,
    # une ellipse pour le reste. Rendre toutes les pages ferait un pied de liste plus long que
    # le tableau dès quelques centaines de démarches.
    PAGINATION_NEIGHBOURS = 1

    def delivery_pagination_pages(pagination)
      total = pagination.total_pages
      current = pagination.current_page
      shown = [1, total, *(current - PAGINATION_NEIGHBOURS..current + PAGINATION_NEIGHBOURS)]
        .select { |page| page.between?(1, total) }.uniq.sort

      shown.each_with_object([]) do |page, list|
        list << :gap if list.last.is_a?(Integer) && page > list.last + 1
        list << page
      end
    end

    # DSFR désactive un contrôle de pagination par l'ABSENCE de `href` — la règle est
    # `a.fr-pagination__link:not([href])`, pas une classe. Le lien reste donc rendu, annoncé et à
    # sa place : un contrôle qui disparaît entre deux pages déplace la navigation sous
    # l'utilisateur, là où un contrôle désactivé reste prévisible. `aria-disabled` double la
    # règle CSS pour les technologies d'assistance.
    def delivery_pagination_step(label, modifier, href: nil)
      classes = "fr-pagination__link fr-pagination__link--#{modifier} fr-pagination__link--lg-label"
      return link_to(label, href, class: classes) if href

      tag.a(label, class: classes, "aria-disabled": true, role: "link")
    end

    # La page courante : `aria-current="page"` et pas de `href`. DSFR ne met en évidence et ne
    # coupe le pointeur que sur cette combinaison précise.
    def delivery_pagination_page(number, href: nil)
      title = t("portail.deliveries.pagination.page", number: number)
      return link_to(number, href, class: "fr-pagination__link", title: title) if href

      tag.a(number, class: "fr-pagination__link", "aria-current": "page", title: title)
    end

    private

    # Format long, et non abrégé : « jeudi 20 août 2026 14h30 » se lit sans effort, là où
    # « 20 août 14h30 » oblige à deviner l'année et perd le jour de la semaine — celui-là même
    # qui situe une transmission quand on relit un dossier plusieurs semaines après.
    def delivery_time(value) = value ? l(value, format: :long) : MISSING
  end
end
