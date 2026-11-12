# frozen_string_literal: true

require "rails_helper"

# L'aide vit sur le site vitrine : le portail y renvoie depuis l'en-tête et le pied de page,
# que l'agent soit connecté ou non — c'est souvent avant la connexion qu'il la cherche.
RSpec.describe "Portail help link", type: :request do
  def page = Capybara.string(response.body)

  it "offers the help section from the header and the footer to a signed-out visitor" do
    get "/"

    expect(response).to have_http_status(:success)
    expect(page.find(".fr-header__tools-links")).to have_link(
      "Aide", href: "https://hubee.numerique.gouv.fr/aide", title: "Aide - nouvelle fenêtre"
    )
    expect(page.find(".fr-footer__bottom-list")).to have_link(
      "Aide", href: "https://hubee.numerique.gouv.fr/aide", title: "Aide - nouvelle fenêtre"
    )
    expect(page).to have_css("a[href='https://hubee.numerique.gouv.fr/aide'][target='_blank'][rel~='noopener']", count: 2)
  end

  it "keeps the help section beside the identity of a signed-in member" do
    sign_in_member
    stub_organisation_subscriptions
    expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(build(:portail_delivery_list))

    get "/teledossiers"

    expect(response).to have_http_status(:success)
    tools = page.find(".fr-header__tools-links")
    expect(tools).to have_link("Aide", href: "https://hubee.numerique.gouv.fr/aide")
    expect(tools).to have_text("Connecté en tant que")
    expect(tools).to have_button("Se déconnecter")
    expect(page.find(".fr-footer__bottom-list")).to have_link("Aide", href: "https://hubee.numerique.gouv.fr/aide")
  end
end
