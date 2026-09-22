# frozen_string_literal: true

require "rails_helper"

# Le fragment que Turbo recharge après un téléchargement. Il rend l'historique du détail, et rien
# d'autre : sa garde doit donc être exactement celle du détail.
RSpec.describe "Portail::Histories", type: :request do
  let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
  let(:path) { "/teledossiers/#{delivery_id}/historique" }

  # Le cas standard du portail : un membre habilité sur le flux du télédossier servi.
  def sign_in_member(data_stream_codes: ["CERTDC"])
    agent = create(:agent, provider_sub: "sub-membre")
    sign_in_via_proconnect(agent: agent)
    membership = Membership.find_by!(agent: agent)
    data_stream_codes.each { |code| create(:data_stream_access, membership: membership, data_stream_code: code) }
    agent
  end

  def sign_in_local_administrator(data_stream_codes: [])
    agent = sign_in_member(data_stream_codes: data_stream_codes)
    Membership.find_by!(agent: agent).update!(role: "local_administrator")
    agent
  end

  describe "GET /teledossiers/:teledossier_id/historique" do
    # Sans `src` : un cadre dont la réponse pointe vers elle-même est refusé par Turbo, qui le
    # vide au lieu de le remplir. Éprouvé en navigateur par le scénario Cucumber.
    it "renders the history inside a frame that does not reference itself" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(
        build(:portail_delivery, events: [build(:portail_event, author: "Alex MARTIN",
          event_type: "attachment.downloaded", content: "certificat.pdf", metadata: {})])
      )

      get path

      expect(response).to have_http_status(:success)
      page = Capybara.string(response.body)
      expect(page).to have_css("turbo-frame#historique[refresh='morph']")
      expect(page).to have_no_css("turbo-frame#historique[src]")
      expect(page).to have_text("Alex MARTIN a téléchargé une pièce")
      expect(page).to have_text("certificat.pdf")
    end

    it "renders the empty history of a delivery without any event" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, events: []))

      get path

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body))
        .to have_text("Aucun événement enregistré pour ce télédossier.")
    end

    it "redirects a signed-out visitor to the home page" do
      get path

      expect(response).to redirect_to(root_path)
    end

    it "renders a not found page when the delivery does not exist" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::NotFound)

      get path

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_text("Page introuvable")
    end

    it "renders a service unavailable page when the upstream fails" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::Unavailable)

      get path

      expect(response).to have_http_status(:service_unavailable)
      expect(Capybara.string(response.body)).to have_text("Service momentanément indisponible")
    end

    # La garde du fragment est celle du détail : un fragment moins gardé que la page servirait
    # l'historique d'un télédossier que l'agent n'a pas le droit d'ouvrir.
    context "reading perimeter" do
      def delivery_on(code) = build(:portail_delivery, data_stream_code: code)

      def expect_a_not_found_page
        get path

        expect(response).to have_http_status(:not_found)
        expect(Capybara.string(response.body)).to have_text("Page introuvable")
        expect(Capybara.string(response.body)).to have_no_text("George DUBOIS")
      end

      def expect_the_history_to_be_served
        get path

        expect(response).to have_http_status(:success)
        expect(Capybara.string(response.body)).to have_css("turbo-frame#historique")
      end

      it "serves the history of a delivery on a data stream the member is habilitated to" do
        sign_in_member(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_the_history_to_be_served
      end

      it "refuses a member on a delivery outside their habilitations" do
        sign_in_member(data_stream_codes: ["AEC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_a_not_found_page
      end

      it "refuses a member without any habilitation" do
        sign_in_member(data_stream_codes: [])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_a_not_found_page
      end

      it "refuses a delivery in a state the portal does not serve" do
        sign_in_member(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find)
          .and_return(build(:portail_delivery, state: "integration_error"))

        expect_a_not_found_page
      end

      # La requête amont porte déjà l'organisation ; ceci vérifie que l'amont l'a respectée.
      it "refuses a delivery the upstream served for another organisation" do
        sign_in_member(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find)
          .and_return(build(:portail_delivery, :of_another_organisation))

        expect_a_not_found_page
      end

      it "refuses a local administrator on a delivery served for another organisation" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Deliveries).to receive(:find)
          .and_return(build(:portail_delivery, :of_another_organisation))

        expect_a_not_found_page
      end

      it "serves any history of their organisation to a local administrator without habilitation" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_the_history_to_be_served
      end
    end
  end
end
