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
    def delivery_state(delivery) = t("portail.deliveries.states.#{delivery.state}", default: MISSING)

    def delivery_transmitted_at(delivery) = delivery_time(delivery.transmitted_at)

    def delivery_updated_at(delivery) = delivery_time(delivery.updated_at)

    # Le demandeur suit la même règle que les dates : la ligne s'affiche toujours, avec son
    # repli quand l'amont n'en sert pas. La masquer ferait disparaître une information sans
    # dire qu'elle manque.
    def delivery_applicant(delivery) = delivery.applicant&.full_name.presence || MISSING

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

    def delivery_time(value) = value ? l(value, format: :short) : MISSING
  end
end
