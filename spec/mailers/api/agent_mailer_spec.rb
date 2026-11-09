# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::AgentMailer do
  describe ".invitation" do
    let(:agent) { create(:agent, first_name: "Alice", last_name: "Martin", email: "alice.martin@ville.fr") }
    let(:html) { Capybara.string(mail.html_part.body.decoded) }
    let(:text) { mail.text_part.body.decoded }

    context "with the name of the organisation" do
      subject(:mail) { described_class.invitation(agent, organization_name: "Mairie de Paris", siret: "21750056000016") }

      it "addresses the agent with the subject of the invitation" do
        expect(mail.to).to eq(["alice.martin@ville.fr"])
        expect(mail.subject).to eq("[HubEE] Votre accès au portail HubEE")
        expect(mail.parts.map(&:mime_type)).to eq(["text/plain", "text/html"])
      end

      it "names the agent, the organisation and the address in the HTML part" do
        expect(html).to have_css("header", text: "HubEE - Hub d'Échange de l'État")
        expect(html).to have_text("Bonjour Alice Martin,")
        expect(html).to have_css("strong", text: "Mairie de Paris")
        expect(html).to have_text("Vous avez désormais accès au portail HubEE pour l'organisation Mairie de Paris (SIRET 21750056000016).", normalize_ws: true)
        expect(html).to have_css("strong", text: "alice.martin@ville.fr", count: 1)
        expect(html).to have_text("Connectez-vous avec l'adresse alice.martin@ville.fr.")
        expect(html).to have_text("Vous n'avez aucun mot de passe HubEE à créer.")
        expect(html).to have_text("Cordialement,")
        expect(html).to have_text("L'équipe HubEE")
        expect(html).to have_css("footer", text: "Ce message vous a été envoyé automatiquement.")
        expect(html).to have_css("footer", text: "Merci de ne pas y répondre.")
      end

      it "links the root of the portal, without any token, from the button and the pasted link" do
        expect(html).to have_link("Accéder au portail HubEE", href: "http://example.com/")
        expect(html).to have_text("copier puis coller le lien suivant dans votre navigateur :")
        expect(html).to have_text("http://example.com/")
        expect(mail.html_part.body.decoded.scan(%r{https?://[^"'\s<]+}).uniq).to eq(["http://example.com/"])
      end

      it "carries the same invitation in the text part" do
        expect(text).to eq(<<~TEXT)
          HubEE - Hub d'Échange de l'État

          Bonjour Alice Martin,

          Vous avez désormais accès au portail HubEE pour l'organisation Mairie de Paris (SIRET 21750056000016).

          La connexion se fait avec ProConnect, en utilisant votre adresse professionnelle alice.martin@ville.fr :

          1. Rendez-vous sur le portail HubEE.
          2. Cliquez sur « S'identifier avec ProConnect ».
          3. Connectez-vous avec l'adresse alice.martin@ville.fr.

          Vous n'avez aucun mot de passe HubEE à créer.

          Accéder au portail HubEE : http://example.com/

          Si vous pensez avoir reçu ce message par erreur, vous pouvez l'ignorer.

          Cordialement,
          L'équipe HubEE

          Ce message vous a été envoyé automatiquement.
          Merci de ne pas y répondre.
        TEXT
      end
    end

    context "without the name of the organisation" do
      subject(:mail) { described_class.invitation(agent, organization_name: nil, siret: "21750056000016") }

      it "designates the organisation by its SIRET in both parts" do
        expect(html).to have_css("strong", text: "l'organisation de SIRET 21750056000016")
        expect(html).to have_text("Vous avez désormais accès au portail HubEE pour l'organisation de SIRET 21750056000016.", normalize_ws: true)
        expect(text).to include("Vous avez désormais accès au portail HubEE pour l'organisation de SIRET 21750056000016.")
        expect(text).not_to include("()")
      end
    end

    context "with markup in the name of the organisation" do
      subject(:mail) { described_class.invitation(agent, organization_name: "<b>Mairie</b> & Cie", siret: "21750056000016") }

      it "escapes it in the HTML part and leaves it as is in the text part" do
        expect(mail.html_part.body.decoded).to include("&lt;b&gt;Mairie&lt;/b&gt; &amp; Cie")
        expect(text).to include("l'organisation <b>Mairie</b> & Cie (SIRET")
      end
    end
  end
end
