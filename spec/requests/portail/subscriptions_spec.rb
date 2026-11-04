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

    it "links each subscription to its detail" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Subscriptions).to receive(:list).and_return(build(:portail_subscription_list,
        subscriptions: [build(:portail_subscription, data_stream_name: "Certificat de décès électronique")]))

      get "/abonnements"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_link("Certificat de décès électronique – CERTDC",
        href: "/abonnements/550e8400-e29b-41d4-a716-446655440000")
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

  describe "GET /abonnements/:id" do
    let(:path) { "/abonnements/550e8400-e29b-41d4-a716-446655440000" }

    it "redirects a signed-out visitor to the home page" do
      get path

      expect(response).to redirect_to(root_path)
    end

    # Rien n'est bouchonné en deçà de la frontière : le détail traverse la gem entière.
    it "shows a subscription the upstream serves for the organisation" do
      sign_in_local_administrator(data_stream_codes: ["CERTDC"])
      use_hub_api_fake_client.add_subscription(build_v2_subscription_detail(
        subscription: build_v2_subscription(organization: build_v2_recipient(
          siret: ProConnectTestHelper::TEST_SIRET, code_insee: ProConnectTestHelper::TEST_INSEE_CODE
        ))
      ))

      get path

      expect(response).to have_http_status(:success)
      # Le nom seul : le code est dans le récapitulatif, sous « Démarche ».
      expect(Capybara.string(response.body)).to have_css("h1", exact_text: "Certificat de décès électronique")
      expect(Capybara.string(response.body)).to have_title("Abonnement Certificat de décès électronique - HubEE")
    end

    # Le rôle × habilitation entier : seul le rôle ouvre la page, l'habilitation n'y change rien.
    context "reading perimeter" do
      it "shows the subscription to a local administrator habilitated on its data stream" do
        sign_in_local_administrator(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(build(:portail_subscription_detail))

        get path

        expect(response).to have_http_status(:success)
        expect(Capybara.string(response.body)).to have_css("h1", text: "CERTDC")
      end

      it "shows the subscription to a local administrator without habilitation" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(build(:portail_subscription_detail))

        get path

        expect(response).to have_http_status(:success)
        expect(Capybara.string(response.body)).to have_css("h1", text: "CERTDC")
      end

      # Comme pour un télédossier, la policy juge l'abonnement lu : un membre le fait lire, même de
      # sa propre organisation, puis reçoit une 404 comme pour une page inexistante, le refus journalisé.
      it "refuses the page to a member habilitated on the data stream" do
        agent = sign_in_member(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Subscriptions).to receive(:find)
          .and_return(build(:portail_subscription_detail, membership: Membership.find_by!(agent: agent)))

        events = capture_semantic_logger_events { get path }

        expect(response).to have_http_status(:not_found)
        expect(Capybara.string(response.body)).to have_css("h1", text: "Page introuvable")
        expect(events).to include(be_a_semantic_logger_event(
          level: :info, message: "Décision d'accès",
          payload_includes: {
            event: "Portail::Access::Refusal", reason: :out_of_perimeter, path: path,
            agent_id: agent.id, membership_id: Membership.find_by!(agent: agent).id
          }
        ))
      end

      it "refuses the page to a member without habilitation" do
        agent = sign_in_member(data_stream_codes: [])
        expect(Portail::HubAPI::Subscriptions).to receive(:find)
          .and_return(build(:portail_subscription_detail, membership: Membership.find_by!(agent: agent)))

        events = capture_semantic_logger_events { get path }

        expect(response).to have_http_status(:not_found)
        expect(Capybara.string(response.body)).to have_css("h1", text: "Page introuvable")
        expect(events).to include(be_a_semantic_logger_event(
          level: :info, message: "Décision d'accès",
          payload_includes: {event: "Portail::Access::Refusal", reason: :out_of_perimeter, path: path}
        ))
      end

      # L'amont n'est pas cru sur parole : l'abonnée servie est confrontée au rattachement.
      it "refuses a subscription the upstream served for another organisation" do
        sign_in_local_administrator(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(build(:portail_subscription_detail,
          subscription: build(:portail_subscription, :of_another_organisation, data_stream_code: "AUTRE")))

        events = capture_semantic_logger_events { get path }

        expect(response).to have_http_status(:not_found)
        expect(Capybara.string(response.body)).to have_css("h1", text: "Page introuvable")
        expect(Capybara.string(response.body)).not_to have_text("AUTRE")
        expect(events).to include(be_a_semantic_logger_event(
          level: :info, message: "Décision d'accès",
          payload_includes: {event: "Portail::Access::Refusal", reason: :out_of_perimeter, path: path}
        ))
      end
    end

    # Ce que l'administrateur local vient vérifier : le canal, l'éditeur, qui reçoit les courriels.
    context "content" do
      def page = Capybara.string(response.body)

      def show_detail(**attributes)
        sign_in_local_administrator(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Subscriptions).to receive(:find)
          .and_return(build(:portail_subscription_detail, **attributes))

        get path
      end

      # Le récapitulatif : un intitulé discret, une valeur mise en avant.
      def value_of(label) = page.find(:xpath, "//dt[normalize-space(.)='#{label}']/following-sibling::dd[1]")

      # Les deux blocs, chacun sous son petit titre, comme sur la fiche d'un télédossier.
      def block(title) = page.find(:xpath, "//section[h2[normalize-space(.)='#{title}']]")

      it "sums up the activity, the access mode and the data stream" do
        show_detail

        expect(response).to have_http_status(:success)
        expect(value_of("État")).to have_css(".fr-badge--success", text: "Actif")
        expect(value_of("Accès")).to have_text("Portail")
        expect(value_of("Démarche")).to have_text("CERTDC")
        expect(page).to have_link("Retour à la liste", href: "/abonnements")
      end

      it "says an unset access mode is not filled in" do
        show_detail(subscription: build(:portail_subscription, access_mode: nil))

        expect(response).to have_http_status(:success)
        expect(value_of("Accès")).to have_text("Non renseignée")
      end

      it "names the editor of an API subscription, its identifiers beneath" do
        show_detail(subscription: build(:portail_subscription, access_mode: "api"),
          delegation: build(:portail_delegation))

        expect(response).to have_http_status(:success)
        expect(block("Éditeur délégué")).to have_css(".fr-text--lg.fr-text--bold", text: "Solution interne")
        expect(block("Éditeur délégué")).to have_text("SIRET 13002526500013 · Code INSEE 75056")
      end

      it "identifies an unnamed editor by its SIRET and INSEE code" do
        show_detail(subscription: build(:portail_subscription, access_mode: "api"),
          delegation: build(:portail_delegation, editor_name: nil))

        expect(response).to have_http_status(:success)
        expect(block("Éditeur délégué")).to have_css(".fr-text--lg.fr-text--bold",
          text: "SIRET 13002526500013 · Code INSEE 75056")
      end

      it "says an API subscription without editor connects by itself" do
        show_detail(subscription: build(:portail_subscription, access_mode: "api"), delegation: nil)

        expect(response).to have_http_status(:success)
        expect(block("Éditeur délégué")).to have_css(".fr-text--bold", text: "Aucun")
        expect(block("Éditeur délégué")).to have_text("Votre structure se connecte elle-même à l'API.")
      end

      # La gem n'en sert pas en mode portail ; l'écran ne s'y fie pas pour autant.
      it "leaves out the editor of a portal subscription" do
        show_detail(delegation: build(:portail_delegation))

        expect(response).to have_http_status(:success)
        expect(page).to have_css("h2", text: "Courriels de télédossiers")
        expect(page).not_to have_text("Éditeur délégué")
        expect(page).not_to have_text("Solution interne")
      end

      # La fréquence est un réglage, pas un statut : du texte, pas un badge.
      it "names the frequency shortly, explains it beneath, and lists the recipients" do
        show_detail(delivery_email_configuration: build(:portail_delivery_email_configuration,
          frequency: "twice_daily", recipients: ["a@commune.fr", "b@commune.fr"]))

        expect(response).to have_http_status(:success)
        emails = block("Courriels de télédossiers")
        expect(emails).to have_css("p.fr-text--bold", text: "Deux fois par jour")
        expect(emails).not_to have_css(".fr-badge")
        expect(emails).to have_text("Un récapitulatif des télédossiers en attente, le matin et à midi")
        expect(emails).to have_css("li", text: "a@commune.fr")
        expect(emails).to have_css("li", text: "b@commune.fr")
      end

      it "hides the recipients when no email is sent" do
        show_detail(delivery_email_configuration: build(:portail_delivery_email_configuration,
          frequency: "none", recipients: ["a@commune.fr"]))

        expect(response).to have_http_status(:success)
        expect(block("Courriels de télédossiers")).to have_text("Aucun courriel")
        expect(page).not_to have_text("a@commune.fr")
      end

      it "shows the recipients of an unknown frequency" do
        show_detail(delivery_email_configuration: build(:portail_delivery_email_configuration,
          frequency: "unknown", recipients: ["a@commune.fr"]))

        expect(response).to have_http_status(:success)
        expect(block("Courriels de télédossiers")).to have_text("Non renseignée")
        expect(block("Courriels de télédossiers")).to have_css("li", text: "a@commune.fr")
      end

      it "says when no address is set" do
        show_detail(delivery_email_configuration: build(:portail_delivery_email_configuration, recipients: []))

        expect(response).to have_http_status(:success)
        expect(block("Courriels de télédossiers")).to have_text("À chaque télédossier")
        expect(block("Courriels de télédossiers")).to have_text("Aucune adresse")
      end

      # Un doublon actif sur le même flux peut faire partir des courriels vers ces adresses : la
      # page ne l'exclut pas, elle montre ce qui est réglé.
      it "warns that an inactive subscription receives nothing, and still shows its settings" do
        show_detail(subscription: build(:portail_subscription, read_package: false))

        expect(response).to have_http_status(:success)
        expect(value_of("État")).to have_css(".fr-badge", text: "Inactif")
        # Une alerte dans le contenu, pas un bandeau `fr-notice`, réservé à l'information de tout le site.
        expect(page).to have_css(".fr-alert.fr-alert--info",
          text: "Abonnement inactif : la structure ne reçoit pas de télédossiers par cet abonnement.")
        expect(block("Courriels de télédossiers")).to have_text("À chaque télédossier")
        expect(block("Courriels de télédossiers")).to have_css("li", text: "contact@commune.fr")
      end
    end

    it "answers not found for a subscription the upstream does not know" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Subscriptions).to receive(:find).and_raise(Portail::HubAPI::NotFound)

      get path

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_css("h1", text: "Page introuvable")
    end

    # Sans bouchon : c'est le refus réel de la gem, avant tout appel, qui doit donner la 404.
    it "answers not found for a malformed id" do
      sign_in_local_administrator
      use_hub_api_fake_client

      get "/abonnements/pas-un-uuid"

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_css("h1", text: "Page introuvable")
    end

    # Un suffixe de format n'est pas un format servi : il fait partie de l'identifiant, que la gem
    # refuse. Un robot qui essaie `.json` reçoit la même 404 que pour tout identifiant malformé.
    it "answers not found for an id carrying a format suffix" do
      sign_in_local_administrator
      use_hub_api_fake_client

      get "/abonnements/pas-un-uuid.json"

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_css("h1", text: "Page introuvable")
    end

    it "says the service is unavailable when the upstream fails" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Subscriptions).to receive(:find).and_raise(Portail::HubAPI::Unavailable)

      get path

      expect(response).to have_http_status(:service_unavailable)
      expect(Capybara.string(response.body)).to have_text("momentanément indisponible")
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
      expect(Capybara.string(response.body)).to have_css("nav.fr-nav a[href='/teledossiers']", text: "Télédossiers")
      expect(Capybara.string(response.body)).not_to have_link("Abonnements")
    end
  end
end
