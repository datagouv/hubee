# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::DeliveryNavigationHelper, type: :helper do
  describe "#delivery_state_menu_link" do
    # Deux états, deux liens : le libellé, la cible et le compteur doivent venir de l'état et
    # du compte reçus, pas d'un rendu figé.
    it "links each state to its page and carries its count" do
      acknowledged = helper.delivery_state_menu_link("acknowledged", 12, current: false)
      done = helper.delivery_state_menu_link("done", 3, current: false)

      expect(Capybara.string(acknowledged))
        .to have_link("Reçue 12", href: "/demarches?statut=acknowledged")
      expect(Capybara.string(done)).to have_link("Traitée 3", href: "/demarches?statut=done")
    end

    # Un état sans démarche reste une entrée du menu : son zéro est une information — c'est
    # lui qui dit à l'agent qu'il n'y a rien à traiter là.
    it "keeps an empty state in the menu with its zero" do
      link = helper.delivery_state_menu_link("refused", 0, current: false)

      expect(Capybara.string(link)).to have_link("Refusée 0", href: "/demarches?statut=refused")
    end

    # DSFR marque l'entrée active par `aria-current`, pas par une classe : c'est cet attribut
    # qui porte à la fois le rendu et l'annonce aux technologies d'assistance.
    it "marks the active state as the current page" do
      link = helper.delivery_state_menu_link("acknowledged", 12, current: true)

      expect(Capybara.string(link)).to have_css("a.fr-sidemenu__link[aria-current='page']")
    end

    it "leaves aria-current out entirely on the other states" do
      link = helper.delivery_state_menu_link("acknowledged", 12, current: false)

      expect(link).not_to include("aria-current")
    end
  end

  describe "#delivery_pagination_pages" do
    it "lists every page while they all fit" do
      pagination = build(:portail_pagination, current_page: 2, total_pages: 4)

      expect(helper.delivery_pagination_pages(pagination)).to eq([1, 2, 3, 4])
    end

    # Une liste de plusieurs centaines de pages ferait un pied plus long que le tableau : on
    # garde les extrémités, la page courante et ses voisines, et on marque les trous.
    it "keeps the ends and the current neighbourhood, and marks the gaps" do
      pagination = build(:portail_pagination, current_page: 20, total_pages: 40)

      expect(helper.delivery_pagination_pages(pagination)).to eq([1, :gap, 19, 20, 21, :gap, 40])
    end

    # Aux extrémités, il n'y a qu'un seul trou : une ellipse de part et d'autre suggérerait des
    # pages qui n'existent pas. Éprouvé aux deux bouts — un fenêtrage qui ne saurait compter
    # que vers la droite passerait un test à sens unique.
    it "opens no gap where the neighbourhood already touches an end" do
      low = build(:portail_pagination, current_page: 2, total_pages: 40)
      high = build(:portail_pagination, current_page: 39, total_pages: 40)

      expect(helper.delivery_pagination_pages(low)).to eq([1, 2, 3, :gap, 40])
      expect(helper.delivery_pagination_pages(high)).to eq([1, :gap, 38, 39, 40])
    end

    # Les positions extrêmes de la page courante : la fenêtre ne doit ni déborder sous 1, ni
    # au-delà de la dernière page.
    it "stays within bounds when the current page is an end itself" do
      first = build(:portail_pagination, current_page: 1, total_pages: 40)
      last = build(:portail_pagination, current_page: 40, total_pages: 40)

      expect(helper.delivery_pagination_pages(first)).to eq([1, 2, :gap, 40])
      expect(helper.delivery_pagination_pages(last)).to eq([1, :gap, 39, 40])
    end

    # Le gabarit ne rend pas de pagination à une page, mais le helper reste défini dessus :
    # personne n'a à connaître cette convention pour l'appeler sans risque.
    it "serves the single page when there is only one" do
      pagination = build(:portail_pagination, current_page: 1, total_pages: 1)

      expect(helper.delivery_pagination_pages(pagination)).to eq([1])
    end
  end
end
