# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Portail home DSFR layout", type: :system do
  it "renders the DSFR socle on the home page" do
    visit "/"

    # Skip links (RGAA)
    expect(page).to have_link("Contenu", href: "#content")

    # Header / landmark banner
    expect(page).to have_css("header.fr-header[role='banner']")
    expect(page).to have_content("HubEE")
    expect(page).to have_content("Plateforme d'échange sécurisé de fichiers entre administrations")

    # Navigation principale
    expect(page).to have_link("Accueil", href: "/")

    # Landmark main + contenu de la page d'accueil (placeholder post-auth)
    expect(page).to have_css("main#content[role='main']")
    expect(page).to have_content("Portail HubEE")

    # Footer / landmark contentinfo + liens légaux obligatoires DSFR
    expect(page).to have_css("footer.fr-footer[role='contentinfo']#footer")
    expect(page).to have_link("Mentions légales")
    expect(page).to have_link("Données personnelles")

    # Hotwire câblé (importmap rendu dans le layout)
    expect(page).to have_css("script[type='importmap']", visible: :all)
  end
end
