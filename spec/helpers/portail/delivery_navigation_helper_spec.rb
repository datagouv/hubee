# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::DeliveryNavigationHelper, type: :helper do
  describe "#delivery_state_menu_link" do
    def criteria(**params) = Portail::Delivery::Criteria.from_params(params)

    # Deux états : le libellé, la cible et le compteur doivent venir des valeurs reçues.
    it "links each state to its page and carries its count" do
      acknowledged = helper.delivery_state_menu_link("acknowledged", 12, criteria: criteria)
      done = helper.delivery_state_menu_link("done", 3, criteria: criteria)

      expect(Capybara.string(acknowledged))
        .to have_link("Reçue 12", href: "/demarches?statut=acknowledged")
      expect(Capybara.string(done)).to have_link("Traitée 3", href: "/demarches?statut=done")
      # Le lien DSFR est une boîte flex : sans marge, le compteur colle au libellé.
      expect(Capybara.string(done)).to have_css("a > span.fr-ml-auto.fr-pl-1w", text: "3")
    end

    # Le zéro est une information : il dit qu'il n'y a rien à traiter là.
    it "keeps an empty state in the menu with its zero" do
      link = helper.delivery_state_menu_link("refused", 0, criteria: criteria)

      expect(Capybara.string(link)).to have_link("Refusée 0", href: "/demarches?statut=refused")
    end

    # Le filtre et le tri suivent d'un état à l'autre : seul l'état change.
    it "carries the filters and the sort into the other state" do
      link = helper.delivery_state_menu_link("done", 3,
        criteria: criteria(statut: "transmitted", flux: "CERTDC", du: "2026-08-01", tri: "updated_at"))

      expect(Capybara.string(link))
        .to have_link("Traitée 3", href: "/demarches?du=2026-08-01&flux%5B%5D=CERTDC&statut=done&tri=updated_at")
    end

    it "marks the active state as the current page" do
      link = helper.delivery_state_menu_link("acknowledged", 12, criteria: criteria(statut: "acknowledged"))

      expect(Capybara.string(link)).to have_css("a.fr-sidemenu__link[aria-current='page']")
    end

    it "leaves aria-current out entirely on the other states" do
      link = helper.delivery_state_menu_link("acknowledged", 12, criteria: criteria(statut: "done"))

      expect(link).not_to include("aria-current")
    end
  end

  describe "#delivery_sort_header" do
    def criteria(**params) = Portail::Delivery::Criteria.from_params(params)

    # Le tri par défaut est un vrai tri : annoncé comme tel dès la première page.
    it "announces the sorted column and offers to reverse it" do
      header = helper.delivery_sort_header("transmitted_at", criteria)

      expect(Capybara.string(header)).to have_css("th[scope='col'][aria-sort='descending']")
      expect(Capybara.string(header)).to have_link("Transmise le", href: "/demarches?ordre=asc&statut=transmitted")
      expect(Capybara.string(header)).to have_css("a.fr-icon-arrow-down-line[title='Trier du plus ancien au plus récent']")
    end

    it "offers the other column from the most recent, unannounced and without icon" do
      header = helper.delivery_sort_header("updated_at", criteria(flux: "CERTDC"))

      expect(Capybara.string(header)).to have_css("th[scope='col']:not([aria-sort])")
      expect(Capybara.string(header))
        .to have_link("Mise à jour le", href: "/demarches?flux%5B%5D=CERTDC&statut=transmitted&tri=updated_at")
      expect(Capybara.string(header)).to have_no_css("a[class*='fr-icon']")
    end

    it "reverses an ascending sort back to descending" do
      header = helper.delivery_sort_header("updated_at", criteria(tri: "updated_at", ordre: "asc"))

      expect(Capybara.string(header)).to have_css("th[aria-sort='ascending'] a.fr-icon-arrow-up-line")
      expect(Capybara.string(header))
        .to have_link("Mise à jour le", href: "/demarches?statut=transmitted&tri=updated_at")
    end
  end

  describe "#delivery_pagination_step" do
    # Un segment désactivé reste rendu : il doit rester explicite lui aussi.
    it "titles the step whether it leads somewhere or not" do
      reachable = helper.delivery_pagination_step("Page suivante", "next", href: "/demarches?page=2")
      disabled = helper.delivery_pagination_step("Page précédente", "prev")

      expect(Capybara.string(reachable))
        .to have_css("a.fr-pagination__link--next[title='Page suivante'][href='/demarches?page=2']")
      expect(Capybara.string(disabled))
        .to have_css("a.fr-pagination__link--prev[title='Page précédente'][aria-disabled='true']:not([href])")
    end
  end

  describe "#delivery_pagination_pages" do
    it "lists every page while they all fit" do
      pagination = build(:portail_pagination, current_page: 2, total_pages: 4)

      expect(helper.delivery_pagination_pages(pagination)).to eq([1, 2, 3, 4])
    end

    it "keeps the ends and the current neighbourhood, and marks the gaps" do
      pagination = build(:portail_pagination, current_page: 20, total_pages: 40)

      expect(helper.delivery_pagination_pages(pagination)).to eq([1, :gap, 19, 20, 21, :gap, 40])
    end

    # Éprouvé aux deux bouts : un fenêtrage à sens unique passerait un test à sens unique.
    it "opens no gap where the neighbourhood already touches an end" do
      low = build(:portail_pagination, current_page: 2, total_pages: 40)
      high = build(:portail_pagination, current_page: 39, total_pages: 40)

      expect(helper.delivery_pagination_pages(low)).to eq([1, 2, 3, :gap, 40])
      expect(helper.delivery_pagination_pages(high)).to eq([1, :gap, 38, 39, 40])
    end

    it "stays within bounds when the current page is an end itself" do
      first = build(:portail_pagination, current_page: 1, total_pages: 40)
      last = build(:portail_pagination, current_page: 40, total_pages: 40)

      expect(helper.delivery_pagination_pages(first)).to eq([1, 2, :gap, 40])
      expect(helper.delivery_pagination_pages(last)).to eq([1, :gap, 39, 40])
    end

    it "serves the single page when there is only one" do
      pagination = build(:portail_pagination, current_page: 1, total_pages: 1)

      expect(helper.delivery_pagination_pages(pagination)).to eq([1])
    end
  end
end
