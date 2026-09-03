# frozen_string_literal: true

module Portail
  # Se déplacer dans les démarches : le menu d'états et la pagination.
  module DeliveryNavigationHelper
    include Portail::DeliveriesHelper

    # DSFR marque l'entrée active par `aria-current`, et `nil` ne rend aucun attribut. Le
    # compteur est du texte, pas un badge : le DSFR réserve le badge à un usage non cliquable.
    def delivery_state_menu_link(state, count, current:)
      link_to(demarches_path(statut: state), class: "fr-sidemenu__link",
        "aria-current": ("page" if current)) do
        safe_join([
          delivery_state_label(state),
          tag.span(count, class: "fr-text--sm fr-text-mention--grey")
        ], " ")
      end
    end

    # Les extrémités, la page courante et ses voisines, une ellipse pour le reste.
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

    # DSFR désactive un contrôle de pagination par l'absence de `href`, pas par une classe ; le
    # lien reste rendu à sa place. `title` sur chaque segment : sous le point de rupture LG, le
    # libellé est rogné et l'infobulle est ce qui reste.
    def delivery_pagination_step(label, modifier, href: nil)
      classes = "fr-pagination__link fr-pagination__link--#{modifier} fr-pagination__link--lg-label"
      return link_to(label, href, class: classes, title: label) if href

      tag.a(label, class: classes, title: label, "aria-disabled": true, role: "link")
    end

    # La page courante : `aria-current="page"` et pas de `href`, la combinaison que DSFR met
    # en évidence.
    def delivery_pagination_page(number, href: nil)
      title = t("portail.deliveries.pagination.page", number: number)
      return link_to(number, href, class: "fr-pagination__link", title: title) if href

      tag.a(number, class: "fr-pagination__link", "aria-current": "page", title: title)
    end
  end
end
