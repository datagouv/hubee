# frozen_string_literal: true

require "rails_helper"

# Le portail ne connaît que ses propres modèles : ces exemples bouchonnent Portail::HubAPI et
# construisent des Portail::Delivery. Ce que la gem rend et comment il est traduit est éprouvé
# dans le spec de la frontière ; que la chaîne entière tienne, dans les scénarios Cucumber.
RSpec.describe "Portail::Deliveries", type: :request do
  # Le cas standard du portail : un agent membre, habilité sur le flux des démarches servies.
  # Les exemples d'affichage se jouent dans cette situation ; les autres combinaisons rôle ×
  # habilitation vivent dans les contextes « reading perimeter ».
  def sign_in_member(process_codes: ["CERTDC"])
    agent = create(:agent, provider_sub: "sub-membre")
    sign_in_via_proconnect(agent: agent)
    membership = Membership.find_by!(agent: agent)
    process_codes.each { |code| create(:process_access, membership: membership, process_code: code) }
    agent
  end

  def sign_in_local_administrator(process_codes: [])
    agent = sign_in_member(process_codes: process_codes)
    Membership.find_by!(agent: agent).update!(role: "local_administrator")
    agent
  end

  describe "GET /demarches" do
    it "redirects a signed-out visitor to the home page" do
      get "/demarches"

      expect(response).to redirect_to(root_path)
    end

    it "lists the deliveries of the agent organisation" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .and_return(build(:portail_delivery_list, deliveries: [build(:portail_delivery_summary)]))

      get "/demarches"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("DGS-CERTDC-0000000000001-01")
      expect(Capybara.string(response.body)).to have_text("CERTDC")
    end

    it "opens on the transmitted state by default" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .with(hash_including(state: "transmitted", page: 1))
        # Le hash complet que reçoit la frontière est éprouvé dans le spec du query object.
        .and_return(build(:portail_delivery_list))

      get "/demarches"
    end

    it "honours the state and the page requested as parameters" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        # Le hash complet que reçoit la frontière est éprouvé dans le spec du query object.
        .with(hash_including(state: "acknowledged", page: 2))
        .and_return(build(:portail_delivery_list))

      get "/demarches", params: {statut: "acknowledged", page: "2"}
    end

    # Le menu ne connaît aucune liste d'états : il rend ce que l'amont a compté, dans l'ordre
    # reçu. Un état ajouté en amont apparaîtrait donc sans qu'on touche à un gabarit.
    it "offers every state the upstream counted, with its total" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(
        build(:portail_delivery_list,
          counts_by_state: {"transmitted" => 12, "acknowledged" => 3, "done" => 41})
      )

      get "/demarches"

      expect(response).to have_http_status(:success)

      menu = Capybara.string(response.body).find("nav.fr-sidemenu")
      expect(menu).to have_link("Transmise 12", href: "/demarches?statut=transmitted")
      expect(menu).to have_link("Reçue 3", href: "/demarches?statut=acknowledged")
      expect(menu).to have_link("Traitée 41", href: "/demarches?statut=done")
    end

    it "marks the state being shown as the current page in the menu" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .and_return(build(:portail_delivery_list, counts_by_state: {"done" => 41}))

      get "/demarches?statut=done"

      expect(response).to have_http_status(:success)

      expect(Capybara.string(response.body))
        .to have_css("nav.fr-sidemenu a[aria-current='page']", text: "Traitée")
    end

    # Le menu SURVIT à l'état vide : sorti du quadrillage, le message laisserait l'agent
    # devant une page sans issue, alors que le compteur d'un autre état lui dit où aller.
    it "keeps the state menu alongside an empty state" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .and_return(build(:portail_delivery_list, deliveries: [],
          counts_by_state: {"transmitted" => 0, "done" => 41}))

      get "/demarches"

      expect(response).to have_http_status(:success)

      expect(Capybara.string(response.body)).to have_text("Aucune démarche dans cet état")
      expect(Capybara.string(response.body))
        .to have_link("Traitée 41", href: "/demarches?statut=done")
    end

    # L'amont ne sert qu'un état à la fois : une colonne « État » serait constante sur toute
    # la hauteur du tableau, et le titre comme le menu le disent déjà.
    it "does not repeat the filtered state on every row" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .and_return(build(:portail_delivery_list, deliveries: [build(:portail_delivery_summary)]))

      get "/demarches"

      expect(response).to have_http_status(:success)

      headers = Nokogiri::HTML(response.body).css("table thead th").map(&:text)
      expect(headers).to eq(["Numéro", "Flux", "Transmise le", "Mise à jour le"])
    end

    # L'échelle avant la lecture : douze dossiers ou sept cents ne se parcourent pas de la
    # même façon, et ça ne se déduit pas d'un numéro de dernière page.
    it "announces how many deliveries there are before the first row" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(
        build(:portail_delivery_list, deliveries: [build(:portail_delivery_summary)],
          pagination: build(:portail_pagination, total: 637, total_pages: 26))
      )

      get "/demarches"

      expect(response).to have_http_status(:success)

      expect(Capybara.string(response.body)).to have_text("637 démarches")
    end

    # Décision de produit : un filtre que l'amont refuse donne une erreur affichée. Le
    # réinitialiser en silence rendrait une liste qui ne dit pas ce qu'elle montre.
    it "shows the refusal when the upstream rejects the requested filter" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .and_raise(Portail::HubAPI::InvalidRequest)

      get "/demarches", params: {statut: "n-importe-quoi"}

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("L'état ou la page demandés n'existent pas")
    end

    # Un paramètre non scalaire — `?statut[]=…`, forgé à la main — suit le même chemin qu'une
    # valeur inconnue : sérialisé en chaîne, refusé par l'amont, montré à l'agent. Rien n'est
    # bouchonné en deçà de la frontière : c'est le vrai refus de la gem qui doit se produire.
    it "shows the refusal for a non-scalar state parameter" do
      sign_in_member
      use_hub_api_fake_client

      get "/demarches", params: {statut: ["transmitted"]}

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("L'état ou la page demandés n'existent pas")
    end

    it "shows the refusal for a non-scalar page parameter" do
      sign_in_member
      use_hub_api_fake_client

      get "/demarches", params: {page: ["2"]}

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("L'état ou la page demandés n'existent pas")
    end

    it "explains the lack of habilitation instead of showing a mute empty table" do
      sign_in_member(process_codes: [])
      # Un périmètre vide ne part jamais en aval — il y vaudrait « aucun filtre ».
      expect(Portail::HubAPI::Deliveries).not_to receive(:list)

      get "/demarches"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("aucun flux")
    end

    # Une panne est un incident : la page se rend quand même, et quelqu'un est réveillé.
    it "renders the page with an alert and reports the outage" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_raise(Portail::HubAPI::Unavailable)
      expect(Sentry).to receive(:capture_exception)

      get "/demarches"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("momentanément indisponible")
    end

    # Le pendant du précédent, et la moitié qui compte : un robot qui balaie des URL suffirait
    # à noyer Sentry sous des refus parfaitement normaux. La distinction ne tient qu'à ces deux
    # exemples — le code, lui, ne dit pas tout seul qu'il ne faut pas alerter.
    it "does not report a filter the upstream refuses" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_raise(Portail::HubAPI::InvalidRequest)
      expect(Sentry).not_to receive(:capture_exception)

      get "/demarches", params: {statut: "n-importe-quoi"}
    end

    # `?page=` vide est ce qu'un formulaire soumet avec un champ vide, pas un paramètre
    # trafiqué : il retombe sur la première page au lieu de produire une page d'erreur.
    it "falls back to the first page when the page parameter is empty" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        # Seule la page est l'objet de cet exemple ; le reste du hash est éprouvé plus haut.
        .with(hash_including(page: 1))
        .and_return(build(:portail_delivery_list))

      get "/demarches", params: {page: ""}
    end

    # La factory fixe `total_pages` à 1 : sans un résultat multi-pages, tout le partial reste un
    # chemin mort, que la couverture de branche ne signale pas — elle n'instrumente pas les
    # gabarits.
    it "renders the pagination when the result spans several pages" do
      sign_in_member
      pagination = build(:portail_pagination, current_page: 2, total_pages: 5)
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(
        build(:portail_delivery_list, pagination: pagination,
          deliveries: [build(:portail_delivery_summary)])
      )

      get "/demarches", params: {page: "2"}

      expect(response).to have_http_status(:success)

      page = Capybara.string(response.body)
      expect(page).to have_link("Page précédente", href: demarches_path(statut: "transmitted", page: 1))
      expect(page).to have_link("Page suivante", href: demarches_path(statut: "transmitted", page: 3))
      # La page courante est marquée et n'est pas un lien : c'est ce que DSFR met en évidence.
      expect(page).to have_css("a.fr-pagination__link[aria-current='page']", text: "2")
    end

    # L'ellipse porte la classe DSFR du segment : c'est elle qui l'aligne sur ses voisins.
    it "marks the elided pages with the DSFR segment" do
      sign_in_member
      pagination = build(:portail_pagination, current_page: 20, total_pages: 40)
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(
        build(:portail_delivery_list, pagination: pagination,
          deliveries: [build(:portail_delivery_summary)])
      )

      get "/demarches", params: {page: "20"}

      expect(response).to have_http_status(:success)
      elided = Nokogiri::HTML(response.body).css("nav.fr-pagination span.fr-pagination__link")
      expect(elided.map { |span| span.text.strip }).to eq(["…", "…"])
    end

    # Les contrôles restent rendus et désactivés plutôt que de disparaître : un contrôle qui
    # s'évanouit entre deux pages déplace la navigation sous l'utilisateur.
    it "keeps the previous control in place, disabled, on the first page" do
      sign_in_member
      pagination = build(:portail_pagination, current_page: 1, total_pages: 3)
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(
        build(:portail_delivery_list, pagination: pagination,
          deliveries: [build(:portail_delivery_summary)])
      )

      get "/demarches"

      expect(response).to have_http_status(:success)

      expect(Capybara.string(response.body))
        .to have_css("a.fr-pagination__link--prev[aria-disabled='true']:not([href])")
    end

    # La matrice rôle × habilitation, côté liste. Une liste d'habilitations renseignée borne
    # tout le monde, administrateur local compris ; le rôle ne tranche que le sens d'une liste
    # vide. La règle est éprouvée dans le spec de la policy — ici, on constate ce qui part
    # réellement à la frontière pour chaque combinaison. Le cas « membre sans habilitation »
    # vit plus haut, avec le message qui l'explique.
    context "reading perimeter" do
      it "filters the list on the codes a member is habilitated to" do
        sign_in_member(process_codes: ["CERTDC", "AEC"])
        expect(Portail::HubAPI::Deliveries).to receive(:list)
          # Le reste du hash est éprouvé dans le spec du query object.
          .with(hash_including(data_stream_codes: match_array(["CERTDC", "AEC"])))
          .and_return(build(:portail_delivery_list))

        get "/demarches"

        expect(response).to have_http_status(:success)
      end

      it "filters the list of a local administrator with named habilitations too" do
        sign_in_local_administrator(process_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:list)
          # Le reste du hash est éprouvé dans le spec du query object.
          .with(hash_including(data_stream_codes: ["CERTDC"]))
          .and_return(build(:portail_delivery_list))

        get "/demarches"

        expect(response).to have_http_status(:success)
      end

      it "leaves a local administrator without habilitation unfiltered" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Deliveries).to receive(:list)
          # Le reste du hash est éprouvé dans le spec du query object.
          .with(hash_including(data_stream_codes: []))
          .and_return(build(:portail_delivery_list))

        get "/demarches"

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /demarches/:id" do
    let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }

    it "redirects a signed-out visitor to the home page" do
      get "/demarches/#{delivery_id}"

      expect(response).to redirect_to(root_path)
    end

    it "shows the delivery metadata, applicant included" do
      sign_in_member
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
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, applicant: nil))

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("Demandeur")
      value = Nokogiri::HTML(response.body)
        .xpath("//dt[normalize-space()='Demandeur']/following-sibling::dd[1]").text
      expect(value).to eq("—")
    end

    it "inventories the pieces that came with the deposit" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(
        build(:portail_delivery, attachments: [build(:portail_attachment,
          filename: "certificat.pdf", byte_size: 2048, state: "rejected")])
      )

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      expect(Capybara.string(response.body)).to have_text("certificat.pdf")
      expect(Capybara.string(response.body)).to have_text("2 ko")
      expect(Capybara.string(response.body)).to have_css("p.fr-badge", text: "Rejetée")
    end

    # L'amont ne sert aucun binaire : la page doit le DIRE, sinon l'agent cherche un lien qui
    # n'existe pas. Et surtout, aucune ligne de l'inventaire ne doit prétendre en être un.
    it "promises no download it cannot honour" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      expect(Capybara.string(response.body))
        .to have_text("Les pièces se consultent depuis votre système d'information")
      rows = Nokogiri::HTML(response.body).css("table tbody a")
      expect(rows).to be_empty
    end

    # Deux magasins en amont, deux sections ici : une pièce arrivée en cours d'instruction ne
    # dit pas la même chose qu'une pièce déposée d'emblée, et la fusionner perdrait son quand.
    it "keeps the pieces added later in their own section, with their provenance" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(
        build(:portail_delivery,
          attachments: [build(:portail_attachment, filename: "depot.pdf")],
          events: [build(:portail_event, event_type: "attachment.created",
            author: "Camille MARTIN", metadata: {},
            attachments: [build(:portail_attachment, id: "b2", filename: "complement.pdf")])])
      )

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      page = Capybara.string(response.body)
      expect(page).to have_text("Pièces du dépôt")
      expect(page).to have_text("depot.pdf")
      expect(page).to have_text("Pièces ajoutées ensuite")
      expect(page).to have_text("complement.pdf")
      expect(page).to have_text("Camille MARTIN")
    end

    # RGAA : chaque tableau porte un titre. En `<caption>` masqué visuellement — les sections
    # ont déjà leur titre à l'écran, et celui d'un inventaire d'event dit aussi sa provenance.
    it "titles each attachments table for assistive technologies" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(
        build(:portail_delivery,
          attachments: [build(:portail_attachment)],
          events: [build(:portail_event, event_type: "attachment.created", metadata: {},
            created_at: Time.zone.local(2026, 1, 10, 16, 16),
            attachments: [build(:portail_attachment, id: "b2")])])
      )

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      captions = Nokogiri::HTML(response.body).css("table caption").map { |c| c.text.strip }
      expect(captions).to contain_exactly(
        "Pièces du dépôt", "Pièces ajoutées ensuite — Samedi 10/01 - 16:16"
      )
    end

    it "says so plainly when nothing was attached at all" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, attachments: [], events: []))

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      page = Capybara.string(response.body)
      expect(page).to have_text("Aucune pièce n'accompagnait le dépôt.")
      expect(page).to have_text("Aucune pièce n'a été ajoutée depuis le dépôt.")
      expect(page).to have_text("Aucun événement enregistré pour cette démarche.")
    end

    it "renders the history with both ends of each state change" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(
        build(:portail_delivery, events: [build(:portail_event,
          event_type: "delivery.state_changed", content: "Dossier pris en charge",
          metadata: {from_state: "transmitted", to_state: "acknowledged"})])
      )

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      page = Capybara.string(response.body)
      expect(page).to have_text("George DUBOIS a modifié le statut : Transmise → Reçue")
      expect(page).to have_text("Dossier pris en charge")
    end

    # La frise groupe par mois : sans ce repère, une instruction étalée sur un trimestre
    # devient une colonne d'horodatages où plus rien ne se situe.
    it "opens a group per month in the history" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(
        build(:portail_delivery, events: [
          build(:portail_event, id: "jan", created_at: Time.zone.local(2026, 1, 10, 16, 16)),
          build(:portail_event, id: "feb", created_at: Time.zone.local(2026, 2, 3, 9, 0))
        ])
      )

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      months = Nokogiri::HTML(response.body).css(".delivery-timeline__month").map { |m| m.text.strip }
      expect(months).to eq(["Février 2026", "Janvier 2026"])
      expect(Capybara.string(response.body)).to have_text("Samedi 10/01 - 16:16")
    end

    # Ce que l'amont promet à la personne concernée, et seulement quand il le promet : un
    # changement d'état n'a rien transmis à personne, l'annoncer serait mentir à l'agent.
    it "notes what actually reached the applicant, and nothing else" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(
        build(:portail_delivery, events: [
          build(:portail_event, event_type: "message.created", metadata: {internal: false})
        ])
      )

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      expect(Capybara.string(response.body))
        .to have_text("Information transmise à la personne concernée.")
    end

    it "stays silent about a broadcast the upstream never claimed" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(
        build(:portail_delivery, events: [
          build(:portail_event, event_type: "message.created", metadata: {internal: true})
        ])
      )

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      # Assertion négative seule : la note absente est tout l'objet de l'exemple, et la page
      # rendue autour d'elle est déjà éprouvée par l'exemple précédent.
      expect(Capybara.string(response.body))
        .to have_no_text("Information transmise à la personne concernée.")
    end

    # Réservé aux SI par le contrat amont, affiché sur décision métier du 2026-09-01. Cet
    # exemple est le garde-fou de cette décision : si elle s'inverse, c'est lui qui tombe et
    # qui rappelle où se fait la coupure.
    it "shows the SI comment, as decided, and labels it for what it is" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(
        build(:portail_delivery, events: [build(:portail_event,
          si_comment: "retry #2 après timeout passerelle")])
      )

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      page = Capybara.string(response.body)
      expect(page).to have_text("Commentaire à destination des SI")
      expect(page).to have_text("retry #2 après timeout passerelle")
    end

    it "situates the delivery with a breadcrumb and states it at a glance" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, state: "done"))

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      page = Capybara.string(response.body)
      expect(page).to have_css("nav.fr-breadcrumb a[aria-current='page']",
        text: "DGS-CERTDC-0000000000001-01")
      # L'état ouvre le récapitulatif et n'en sort pas : le sortir du bloc le ferait flotter
      # sous le titre, ce dont on vient précisément de le tirer.
      expect(page).to have_css("dl.delivery-summary p.fr-badge.fr-badge--success", text: "Traitée")
    end

    # Le récapitulatif se lit en couples libellé/valeur, chacun dans sa cellule de grille. Sans
    # l'enveloppe, dt et dd deviennent deux cellules indépendantes et le libellé se décroche de
    # sa valeur — un défaut que seul l'œil attrape, d'où cet exemple sur la structure.
    it "pairs every summary label with its own value" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      cells = Nokogiri::HTML(response.body).css("dl.delivery-summary > div")
      expect(cells.map { |cell| cell.css("dt").text.strip })
        .to eq(["État", "Flux", "Demandeur", "Transmise le", "Mise à jour le"])
      expect(cells.map { |cell| cell.css("dd").count }).to all(eq(1))
    end

    # Le quoi et le qui portent le gras, les dates passent en gris discret. Tout mettre au
    # même niveau typographique revient à ne rien mettre en avant — c'est l'agent qui ferait
    # le tri à chaque lecture, et c'est précisément ce qu'on lui épargne ici.
    it "ranks the summary instead of flattening it" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      summary = Nokogiri::HTML(response.body).at_css("dl.delivery-summary")
      emphasised = summary.css("dd.fr-text--bold").map { |value| value.text.strip }
      muted = summary.css("dd.fr-text-mention--grey").count

      expect(emphasised).to eq(["CERTDC", "George DUBOIS"])
      expect(muted).to eq(2)
    end

    # Deux rangs et non un seul de cinq : ce qu'on vient chercher devant, les horodatages
    # derrière. C'est aussi ce qui laisse aux dates écrites en entier la largeur de tenir sur
    # une ligne — les serrer en quart de bloc annulerait le gain du format long.
    it "splits the summary into what is sought and what merely situates it" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      cells = Nokogiri::HTML(response.body).css("dl.delivery-summary > div").map { |c| c["class"] }
      expect(cells.count { |classes| classes.include?("fr-col-md-4") }).to eq(3)
      expect(cells.count { |classes| classes.include?("fr-col-md-6") }).to eq(2)
    end

    it "gives the same message when the delivery does not exist" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::NotFound)
      # La redirection retraverse la liste : son contenu n'est pas l'objet de cet exemple.
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(build(:portail_delivery_list))

      get "/demarches/#{delivery_id}"

      expect(response).to redirect_to(demarches_path)
      follow_redirect!

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("introuvable ou hors de votre périmètre")
    end

    # L'identifiant vient de l'URL et finit au journal : des retours à la ligne passés en
    # douce y forgeraient de fausses lignes. Il est donc journalisé sous forme inspectée.
    it "logs the unknown identifier without letting it forge log lines" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::NotFound)
      lines = []
      expect(Rails.logger).to receive(:info).at_least(:once) { |line| lines << line }

      # La redirection vers la liste n'est pas suivie : seul le journal est l'objet ici.
      get "/demarches/evil%0Aforged"

      line = lines.grep(/introuvable/).first
      expect(line).to include('"evil\nforged"')
      expect(line).not_to include("\n")
    end

    # La matrice rôle × habilitation, côté détail — le trou que ferme la policy : la liste ne
    # montre pas une démarche hors habilitation, mais son identifiant suffirait à l'ouvrir si
    # personne ne vérifiait à l'entrée. Même règle qu'à la liste : une habilitation nommée
    # borne aussi l'administrateur local, le rôle ne joue qu'à habilitations vides.
    context "reading perimeter" do
      def delivery_on(code) = build(:portail_delivery, data_stream_code: code)

      # La redirection retraverse la liste ; son contenu n'est pas l'objet de ces exemples.
      # Sauf périmètre vide — qui n'appelle jamais l'amont —, l'exemple pose ce bouchon.
      def expect_the_list_to_be_retraversed
        expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(build(:portail_delivery_list))
      end

      def expect_refusal_and_return_to_the_list
        get "/demarches/#{delivery_id}"

        expect(response).to redirect_to(demarches_path)
        follow_redirect!

        expect(response).to have_http_status(:success)
        expect(Capybara.string(response.body)).to have_text("introuvable ou hors de votre périmètre")
      end

      def expect_the_delivery_to_open
        get "/demarches/#{delivery_id}"

        expect(response).to have_http_status(:success)
        expect(Capybara.string(response.body)).to have_text("DGS-CERTDC-0000000000001-01")
      end

      it "opens a delivery on a data stream the member is habilitated to" do
        sign_in_member(process_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_the_delivery_to_open
      end

      it "refuses a member on a delivery outside their habilitations" do
        sign_in_member(process_codes: ["AEC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))
        expect_the_list_to_be_retraversed

        expect_refusal_and_return_to_the_list
      end

      it "refuses a member without any habilitation" do
        sign_in_member(process_codes: [])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_refusal_and_return_to_the_list
      end

      it "opens any delivery to a local administrator without habilitation" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_the_delivery_to_open
      end

      it "opens a delivery inside the habilitations of a local administrator" do
        sign_in_local_administrator(process_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_the_delivery_to_open
      end

      it "refuses a local administrator on a delivery outside their habilitations" do
        sign_in_local_administrator(process_codes: ["AEC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))
        expect_the_list_to_be_retraversed

        expect_refusal_and_return_to_the_list
      end
    end
  end
end
