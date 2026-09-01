# frozen_string_literal: true

module Portail
  # Se déplacer dans les démarches : le menu d'états et la pagination. Le socle des champs
  # (libellés d'état) vit dans DeliveriesHelper, inclus ici.
  module DeliveryNavigationHelper
    include Portail::DeliveriesHelper

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
  end
end
