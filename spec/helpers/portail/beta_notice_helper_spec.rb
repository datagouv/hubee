# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::BetaNoticeHelper, type: :helper do
  # Le mailto décodé : objet et corps tels que le client mail les pré-remplira.
  def mailto_fields(link)
    href = Capybara.string(link).find("a")["href"]
    Rack::Utils.parse_query(href.split("?", 2).last).merge("to" => href[/\Amailto:([^?]+)/, 1])
  end

  describe "#beta_mail_to" do
    it "prefills the support mail with the agent identity, the SIRET and the page" do
      agent = create(:agent, first_name: "Camille", last_name: "Durand", email: "camille.durand@mairie.fr")
      membership = create(:membership, agent:, organization_link: create(:organization_link, siret: "21750001600019"))

      link = helper.beta_mail_to(:support, membership:, page_url: "https://portail.hubee.gouv.fr/teledossiers/42")

      expect(Capybara.string(link)).to have_link("Signaler un problème", class: "fr-notice__link")
      expect(mailto_fields(link)).to eq(
        "to" => "hubee.portail.pilote@numerique.gouv.fr",
        "subject" => "[Portail HubEE V2] Support - SIRET 21750001600019",
        "body" => "Décrivez votre problème :\r\n\r\n\r\n\r\n---\r\n" \
          "Agent : Camille DURAND (camille.durand@mairie.fr)\r\n" \
          "SIRET : 21750001600019\r\n" \
          "Page : https://portail.hubee.gouv.fr/teledossiers/42"
      )
    end

    it "prefills the feedback mail with its own subject and prompt" do
      membership = create(:membership, organization_link: create(:organization_link, siret: "21750001600019"))

      link = helper.beta_mail_to(:feedback, membership:, page_url: "https://portail.hubee.gouv.fr/")

      expect(Capybara.string(link)).to have_link("Partager un retour", class: "fr-notice__link")
      expect(mailto_fields(link)).to include(
        "subject" => "[Portail HubEE V2] Retour - SIRET 21750001600019",
        "body" => start_with("Votre retour, positif ou négatif :\r\n")
      )
    end

    it "keeps only the page for a signed-out visitor" do
      link = helper.beta_mail_to(:support, membership: nil, page_url: "https://portail.hubee.gouv.fr/")

      expect(mailto_fields(link)).to include(
        "subject" => "[Portail HubEE V2] Support",
        "body" => "Décrivez votre problème :\r\n\r\n\r\n\r\n---\r\nPage : https://portail.hubee.gouv.fr/"
      )
    end

    # Les accents de l'objet et du corps : %20 et UTF-8, jamais « + » qu'Outlook affiche tel quel.
    it "percent-encodes spaces and accents" do
      link = helper.beta_mail_to(:support, membership: nil, page_url: "https://portail.hubee.gouv.fr/")

      href = Capybara.string(link).find("a")["href"]
      expect(href).to include("subject=%5BPortail%20HubEE%20V2%5D%20Support")
      expect(href).to include("D%C3%A9crivez%20votre%20probl%C3%A8me")
      expect(href).not_to include("+")
    end
  end

  describe "#beta_notice?" do
    around do |example|
      original = ENV["HIDE_BETA_NOTICE"]
      example.run
    ensure
      ENV["HIDE_BETA_NOTICE"] = original
    end

    flags = {
      "unset" => {value: nil, shown: true},
      "true" => {value: "true", shown: false},
      "false" => {value: "false", shown: true},
      "empty" => {value: "", shown: true}
    }

    flags.each do |label, flag|
      it "is #{flag[:shown] ? "shown" : "hidden"} when HIDE_BETA_NOTICE is #{label}" do
        ENV["HIDE_BETA_NOTICE"] = flag[:value]

        expect(helper.beta_notice?).to eq(flag[:shown])
      end
    end
  end
end
