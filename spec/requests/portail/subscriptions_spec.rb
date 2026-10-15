# frozen_string_literal: true

require "rails_helper"

# Ces exemples bouchonnent Portail::HubAPI et construisent des Portail::Subscription, sauf un qui
# traverse la gem. La traduction est éprouvée dans le spec de la frontière.
RSpec.describe "Portail::Subscriptions", type: :request do
  def rows
    Nokogiri::HTML(response.body).css("table tbody tr").map do |row|
      row.css("td").map { |cell| cell.text.strip }
    end
  end

  describe "GET /abonnements" do
    it "redirects a signed-out visitor to the home page" do
      get "/abonnements"

      expect(response).to redirect_to(root_path)
    end

    # Rien n'est bouchonné en deçà de la frontière : l'abonnement traverse la gem entière.
    it "lists a subscription the upstream serves for the organisation" do
      sign_in_local_administrator(data_stream_codes: ["CERTDC"])
      use_hub_api_fake_client.add_subscription(build_v2_subscription(
        organization: build_v2_recipient(siret: ProConnectTestHelper::TEST_SIRET,
          code_insee: ProConnectTestHelper::TEST_INSEE_CODE),
        data_stream_code: "CERTDC", data_stream_name: "Certificat de décès électronique"
      ))

      get "/abonnements"

      expect(response).to have_http_status(:success)
      expect(rows).to eq([["Certificat de décès électronique – CERTDC", "Portail", "Actif"]])
    end

    # Le rôle × habilitation entier : seul le rôle ouvre la page, et l'habilitation ne restreint
    # pas ce qu'elle montre.
    context "reading perimeter" do
      it "lists every subscription of the organisation to a local administrator habilitated on one data stream" do
        sign_in_local_administrator(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Subscriptions).to receive(:list).and_return(build(:portail_subscription_list,
          subscriptions: [
            build(:portail_subscription, data_stream_code: "CERTDC", data_stream_name: "Certificat de décès électronique"),
            build(:portail_subscription, id: "sub-2", data_stream_code: "AEC", data_stream_name: "Actes d'état civil")
          ]))

        get "/abonnements"

        expect(response).to have_http_status(:success)
        expect(rows.map(&:first)).to eq(["Actes d'état civil – AEC", "Certificat de décès électronique – CERTDC"])
      end

      it "lists every subscription of the organisation to a local administrator without habilitation" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Subscriptions).to receive(:list).and_return(build(:portail_subscription_list,
          subscriptions: [
            build(:portail_subscription, data_stream_code: "CERTDC", data_stream_name: "Certificat de décès électronique"),
            build(:portail_subscription, id: "sub-2", data_stream_code: "AEC", data_stream_name: "Actes d'état civil")
          ]))

        get "/abonnements"

        expect(response).to have_http_status(:success)
        expect(rows.map(&:first)).to eq(["Actes d'état civil – AEC", "Certificat de décès électronique – CERTDC"])
      end

      # Une 404 comme une page inexistante, le refus journalisé ; l'amont n'est pas lu.
      it "refuses the page to a member habilitated on a data stream" do
        agent = sign_in_member(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Subscriptions).not_to receive(:list)

        events = capture_semantic_logger_events { get "/abonnements" }

        expect(response).to have_http_status(:not_found)
        expect(Capybara.string(response.body)).to have_css("h1", text: "Page introuvable")
        expect(events).to include(be_a_semantic_logger_event(
          level: :info, message: "Décision d'accès",
          payload_includes: {
            event: "Portail::Access::Refusal", reason: :out_of_perimeter, path: "/abonnements",
            agent_id: agent.id, membership_id: Membership.find_by!(agent: agent).id
          }
        ))
      end

      it "refuses the page to a member without habilitation" do
        sign_in_member(data_stream_codes: [])
        expect(Portail::HubAPI::Subscriptions).not_to receive(:list)

        get "/abonnements"

        expect(response).to have_http_status(:not_found)
        expect(Capybara.string(response.body)).to have_css("h1", text: "Page introuvable")
      end

      # La requête amont porte l'organisation ; un abonnement d'une autre est écarté, pas montré.
      it "drops a subscription the upstream served for another organisation" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Subscriptions).to receive(:list).and_return(build(:portail_subscription_list,
          subscriptions: [
            build(:portail_subscription, data_stream_code: "CERTDC"),
            build(:portail_subscription, :of_another_organisation, id: "sub-2", data_stream_code: "AEC")
          ]))

        get "/abonnements"

        expect(response).to have_http_status(:success)
        expect(rows.map(&:first)).to eq(["CERTDC"])
      end
    end

    it "tells the access mode and whether the organisation receives the data stream" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Subscriptions).to receive(:list).and_return(build(:portail_subscription_list,
        subscriptions: [
          build(:portail_subscription, data_stream_code: "A_PORTAIL"),
          build(:portail_subscription, id: "sub-2", data_stream_code: "B_API", access_mode: "api"),
          build(:portail_subscription, id: "sub-3", data_stream_code: "C_DORMANT", read_package: false),
          build(:portail_subscription, id: "sub-4", data_stream_code: "D_SANS_CANAL", access_mode: nil)
        ]))

      get "/abonnements"

      expect(response).to have_http_status(:success)
      expect(rows).to eq([
        ["A_PORTAIL", "Portail", "Actif"],
        ["B_API", "API", "Actif"],
        ["C_DORMANT", "Portail", "Inactif"],
        ["D_SANS_CANAL", "—", "Actif"]
      ])
    end

    it "says so when the organisation has no subscription" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Subscriptions).to receive(:list)
        .and_return(build(:portail_subscription_list, subscriptions: []))

      get "/abonnements"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("Votre structure n'a aucun abonnement.")
      expect(Capybara.string(response.body)).not_to have_css("table")
    end

    it "says the list is unavailable when the upstream fails" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Subscriptions).to receive(:list).and_raise(Portail::HubAPI::Unavailable)

      get "/abonnements"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body))
        .to have_text("La liste des abonnements est momentanément indisponible. Réessayez dans quelques instants.")
      expect(Capybara.string(response.body)).not_to have_css("table")
    end
  end

  # L'entrée de menu suit la policy : un membre ne voit pas un lien qui le mènerait à une 404.
  describe "header navigation" do
    it "offers the subscriptions to a local administrator" do
      sign_in_local_administrator
      stub_organisation_subscriptions
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(build(:portail_delivery_list))

      get "/teledossiers"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_css("nav.fr-nav a[href='/abonnements']", text: "Abonnements")
    end

    it "does not offer them to a member" do
      sign_in_member
      stub_organisation_subscriptions
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(build(:portail_delivery_list))

      get "/teledossiers"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_css("nav.fr-nav a", text: "Accueil")
      expect(Capybara.string(response.body)).not_to have_link("Abonnements")
    end
  end
end
