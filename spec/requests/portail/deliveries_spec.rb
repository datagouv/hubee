# frozen_string_literal: true

require "rails_helper"

# Le portail ne connaît que ses propres modèles : ces exemples bouchonnent Portail::HubAPI et
# construisent des Portail::Delivery. Ce que la gem rend et comment il est traduit est éprouvé
# dans le spec de la frontière ; que la chaîne entière tienne, dans les scénarios Cucumber.
RSpec.describe "Portail::Deliveries", type: :request do
  # Administrateur local : son périmètre n'est pas filtré, ce qui isole ce que chaque exemple
  # veut éprouver de la question des habilitations, traitée dans le spec de la policy.
  def sign_in_local_administrator
    agent = create(:agent, provider_sub: "sub-admin")
    sign_in_via_proconnect(agent: agent)
    Membership.find_by!(agent: agent).update!(role: "local_administrator")
    agent
  end

  describe "GET /demarches" do
    it "redirects a signed-out visitor to the home page" do
      get "/demarches"

      expect(response).to redirect_to(root_path)
    end

    it "lists the deliveries of the agent organisation" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        # Le décor global de spec/support/hub_api.rb sert une page vide ; celui-ci la remplace.
        .and_return(build(:portail_delivery_list, deliveries: [build(:portail_delivery_summary)]))

      get "/demarches"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("DGS-CERTDC-0000000000001-01")
      expect(Capybara.string(response.body)).to have_text("CERTDC")
    end

    it "opens on the transmitted state by default" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .with(hash_including(state: "transmitted", page: 1))
        # Le hash complet que reçoit la frontière est éprouvé dans le spec du query object.
        .and_return(build(:portail_delivery_list))

      get "/demarches"
    end

    it "honours the state and the page requested as parameters" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .with(hash_including(state: "acknowledged", page: "2"))
        .and_return(build(:portail_delivery_list))

      get "/demarches", params: {statut: "acknowledged", page: "2"}
    end

    # Décision de produit : un filtre que l'amont refuse donne une erreur affichée. Le
    # réinitialiser en silence rendrait une liste qui ne dit pas ce qu'elle montre.
    it "shows the refusal when the upstream rejects the requested filter" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .and_raise(Portail::HubAPI::InvalidRequest)

      get "/demarches", params: {statut: "n-importe-quoi"}

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("L'état ou la page demandés n'existent pas")
    end

    it "explains the lack of habilitation instead of showing a mute empty table" do
      agent = create(:agent, provider_sub: "sub-membre")
      sign_in_via_proconnect(agent: agent)

      get "/demarches"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("aucun flux")
    end

    context "when the upstream API is failing" do
      it "renders the page with an alert rather than a server error" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Deliveries).to receive(:list).and_raise(Portail::HubAPI::Unavailable)

        get "/demarches"

        expect(response).to have_http_status(:success)
        expect(Capybara.string(response.body)).to have_text("momentanément indisponible")
      end

      # Une panne est un incident : elle réveille quelqu'un.
      it "reports the outage" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Deliveries).to receive(:list).and_raise(Portail::HubAPI::Unavailable)
        expect(Sentry).to receive(:capture_exception)

        get "/demarches"
      end
    end

    # Le pendant du précédent, et la moitié qui compte : un robot qui balaie des URL suffirait
    # à noyer Sentry sous des refus parfaitement normaux. La distinction ne tient qu'à ces deux
    # exemples — le code, lui, ne dit pas tout seul qu'il ne faut pas alerter.
    it "does not report a filter the upstream refuses" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_raise(Portail::HubAPI::InvalidRequest)
      expect(Sentry).not_to receive(:capture_exception)

      get "/demarches", params: {statut: "n-importe-quoi"}
    end

    # `?page=` vide est ce qu'un formulaire soumet avec un champ vide, pas un paramètre
    # trafiqué : il retombe sur la première page au lieu de produire une page d'erreur.
    it "falls back to the first page when the page parameter is empty" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .with(hash_including(page: 1))
        .and_return(build(:portail_delivery_list))

      get "/demarches", params: {page: ""}
    end

    # Le pied de liste n'était rendu par aucun exemple : la factory fixe `total_pages` à 1, donc
    # tout le partial restait un chemin mort — que la couverture de branche ne signale pas, elle
    # n'instrumente pas les gabarits.
    it "renders the pagination when the result spans several pages" do
      sign_in_local_administrator
      pagination = build(:portail_pagination, current_page: 2, total_pages: 5)
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(
        build(:portail_delivery_list, pagination: pagination,
          deliveries: [build(:portail_delivery_summary)])
      )

      get "/demarches", params: {page: "2"}

      page = Capybara.string(response.body)
      expect(page).to have_link("Page précédente", href: demarches_path(statut: "transmitted", page: 1))
      expect(page).to have_link("Page suivante", href: demarches_path(statut: "transmitted", page: 3))
      # La page courante est marquée et n'est pas un lien : c'est ce que DSFR met en évidence.
      expect(page).to have_css("a.fr-pagination__link[aria-current='page']", text: "2")
    end

    # Les contrôles restent rendus et désactivés plutôt que de disparaître : un contrôle qui
    # s'évanouit entre deux pages déplace la navigation sous l'utilisateur.
    it "keeps the previous control in place, disabled, on the first page" do
      sign_in_local_administrator
      pagination = build(:portail_pagination, current_page: 1, total_pages: 3)
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(
        build(:portail_delivery_list, pagination: pagination,
          deliveries: [build(:portail_delivery_summary)])
      )

      get "/demarches"

      expect(Capybara.string(response.body))
        .to have_css("a.fr-pagination__link--prev[aria-disabled='true']:not([href])")
    end
  end

  describe "GET /demarches/:id" do
    let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }

    it "redirects a signed-out visitor to the home page" do
      get "/demarches/#{delivery_id}"

      expect(response).to redirect_to(root_path)
    end

    it "shows the delivery metadata, applicant included" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("DGS-CERTDC-0000000000001-01")
      expect(Capybara.string(response.body)).to have_text("George DUBOIS")
    end

    # La ligne reste affichée avec son repli : la masquer ferait disparaître une information
    # sans dire qu'elle manque. Nokogiri plutôt que Capybara — c'est la valeur rattachée à ce
    # libellé précis qu'on vérifie, donc une position dans le DOM.
    it "renders the applicant line with its fallback when there is no applicant" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, applicant: nil))

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("Demandeur")
      value = Nokogiri::HTML(response.body)
        .xpath("//dt[normalize-space()='Demandeur']/following-sibling::dd[1]").text
      expect(value).to eq("—")
    end

    # Le trou que ferme la policy : la liste ne montre pas cette démarche, mais son
    # identifiant suffirait à l'ouvrir si personne ne vérifiait à l'entrée.
    it "refuses a delivery whose data stream is outside the agent habilitations" do
      agent = create(:agent, provider_sub: "sub-habilite")
      sign_in_via_proconnect(agent: agent)
      create(:process_access, membership: Membership.find_by!(agent: agent), process_code: "AEC")
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, data_stream_code: "CERTDC"))
      # La redirection retraverse la liste : son contenu n'est pas l'objet de cet exemple.
      allow(Portail::HubAPI::Deliveries).to receive(:list).and_return(build(:portail_delivery_list))

      get "/demarches/#{delivery_id}"

      expect(response).to redirect_to(demarches_path)
      follow_redirect!
      expect(Capybara.string(response.body)).to have_text("introuvable ou hors de votre périmètre")
    end

    it "gives the same message when the delivery does not exist" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::NotFound)
      allow(Portail::HubAPI::Deliveries).to receive(:list).and_return(build(:portail_delivery_list))

      get "/demarches/#{delivery_id}"

      expect(response).to redirect_to(demarches_path)
      follow_redirect!
      expect(Capybara.string(response.body)).to have_text("introuvable ou hors de votre périmètre")
    end
  end
end
