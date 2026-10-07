# frozen_string_literal: true

require "rails_helper"

# Le contenu des mails est éprouvé dans le spec du helper ; ici, sa présence sur chaque page.
RSpec.describe "Portail beta notice", type: :request do
  def notice = Capybara.string(response.body).find("main#content > .fr-notice.fr-notice--info")

  def mail_subjects
    notice.all("a.fr-notice__link").map { |link| Rack::Utils.parse_query(link["href"].split("?", 2).last)["subject"] }
  end

  # Le lien d'évitement « Contenu » mène à main#content : le bandeau doit s'y trouver pour être lu.
  it "opens the content of the home page for a signed-out visitor" do
    get "/"

    expect(response).to have_http_status(:success)
    expect(notice).to have_text("Le portail HubEE est en version bêta.")
    expect(notice).to have_text("hubee.portail.pilote@numerique.gouv.fr")
    expect(notice).to have_link("Signaler un problème")
    expect(notice).to have_link("Partager un retour")
    expect(mail_subjects).to eq(["[Portail HubEE V2] Support", "[Portail HubEE V2] Retour"])
  end

  # Sous 576 px, le DSFR passe déjà le titre à la ligne : une coupure de plus y laisserait une ligne vide.
  it "puts the title alone on its line, from the small breakpoint up" do
    get "/"

    expect(response).to have_http_status(:success)
    expect(notice).to have_css("p > br.fr-hidden.fr-unhidden-sm", count: 1)
    lines = notice.find("p").native.inner_html.split(/<br[^>]*>/).map { Capybara.string(it).text.squish }
    expect(lines).to eq([
      "Le portail HubEE est en version bêta.",
      "Un problème ? Signaler un problème. Un avis, positif ou négatif ? Partager un retour. " \
        "Dans les deux cas, vous pouvez aussi écrire à hubee.portail.pilote@numerique.gouv.fr."
    ])
  end

  it "carries the SIRET of the signed-in agent organisation" do
    sign_in_member
    stub_organisation_subscriptions
    expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(build(:portail_delivery_list))

    get "/teledossiers"

    expect(response).to have_http_status(:success)
    expect(mail_subjects).to eq([
      "[Portail HubEE V2] Support - SIRET #{ProConnectTestHelper::TEST_SIRET}",
      "[Portail HubEE V2] Retour - SIRET #{ProConnectTestHelper::TEST_SIRET}"
    ])
  end

  # Une page d'erreur est précisément celle d'où l'on cherche le support.
  it "stays on an error page" do
    sign_in_member
    expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::NotFound)

    get "/teledossiers/94b1b09d-b47f-4480-9b48-93b8b36108f2"

    expect(response).to have_http_status(:not_found)
    expect(notice).to have_link("Signaler un problème")
  end

  context "when HIDE_BETA_NOTICE is true" do
    around do |example|
      original = ENV["HIDE_BETA_NOTICE"]
      ENV["HIDE_BETA_NOTICE"] = "true"
      example.run
    ensure
      ENV["HIDE_BETA_NOTICE"] = original
    end

    it "renders the page without the notice" do
      get "/"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_css("main#content", text: "Portail HubEE")
      expect(Capybara.string(response.body)).not_to have_css(".fr-notice")
    end
  end
end
