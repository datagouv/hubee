# frozen_string_literal: true

require "rails_helper"

# Ces exemples bouchonnent Portail::HubAPI et construisent des Portail::Delivery. La traduction
# de la gem est éprouvée dans le spec de la frontière, la chaîne entière dans Cucumber.
RSpec.describe "Portail::Deliveries", type: :request do
  # Le cas standard du portail : un membre habilité sur le flux des démarches servies.
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

  # L'organisation de l'agent connecté, dans le vocabulaire de la gem : son client bouchonné
  # filtre sur ce couple, comme l'API.
  def upstream_recipient
    build_v2_recipient(siret: ProConnectTestHelper::TEST_SIRET,
      code_insee: ProConnectTestHelper::TEST_INSEE_CODE)
  end

  describe "GET /demarches" do
    it "redirects a signed-out visitor to the home page" do
      get "/demarches"

      expect(response).to redirect_to(root_path)
    end

    # Rien n'est bouchonné en deçà de la frontière : la démarche traverse la gem entière.
    it "lists a delivery the upstream serves for the organisation" do
      sign_in_member
      use_hub_api_fake_client.add_case(
        build_v2_delivery(state: :transmitted, recipient: upstream_recipient)
      )

      get "/demarches"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body))
        .to have_link("DGS-CERTDC-0000000000001-01", href: "/demarches/94b1b09d-b47f-4480-9b48-93b8b36108f2")
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
        # Le hash complet est éprouvé dans le spec de l'étape FetchList.
        .and_return(build(:portail_delivery_list))

      get "/demarches"
    end

    it "honours the state and the page requested as parameters" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        # Le hash complet est éprouvé dans le spec de l'étape FetchList.
        .with(hash_including(state: "acknowledged", page: 2))
        .and_return(build(:portail_delivery_list))

      get "/demarches", params: {statut: "acknowledged", page: "2"}
    end

    # Le menu rend ce que l'amont a compté, dans l'ordre reçu : aucune liste d'états ici.
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

    # Le menu survit à l'état vide : le compteur d'un autre état dit à l'agent où aller.
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

    # L'amont ne sert qu'un état à la fois : une colonne « État » serait constante.
    it "does not repeat the filtered state on every row" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .and_return(build(:portail_delivery_list, deliveries: [build(:portail_delivery_summary)]))

      get "/demarches"

      expect(response).to have_http_status(:success)

      headers = Nokogiri::HTML(response.body).css("table thead th").map(&:text)
      expect(headers).to eq(["Numéro", "Flux", "Transmise le", "Mise à jour le"])
    end

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

    # Un filtre refusé donne une erreur affichée, jamais un filtre réinitialisé en silence.
    it "shows the refusal when the upstream rejects the requested filter" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .and_raise(Portail::HubAPI::InvalidRequest)

      get "/demarches", params: {statut: "n-importe-quoi"}

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("L'état ou la page demandés n'existent pas")
    end

    # Rien n'est bouchonné en deçà de la frontière : c'est le vrai refus de la gem qui se produit.
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
      # Un périmètre vide ne part jamais en aval : il y vaudrait « aucun filtre ».
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

    # Un robot qui balaie des URL noierait Sentry sous des refus normaux.
    it "does not report a filter the upstream refuses" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list).and_raise(Portail::HubAPI::InvalidRequest)
      expect(Sentry).not_to receive(:capture_exception)

      get "/demarches", params: {statut: "n-importe-quoi"}
    end

    # `?page=` vide est ce qu'un formulaire soumet avec un champ vide, pas un paramètre trafiqué.
    it "falls back to the first page when the page parameter is empty" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .with(hash_including(page: 1))
        .and_return(build(:portail_delivery_list))

      get "/demarches", params: {page: ""}
    end

    # La couverture n'instrumente pas les gabarits : sans cet exemple, le partial est un chemin mort.
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
      # La page courante est marquée et n'est pas un lien.
      expect(page).to have_css("a.fr-pagination__link[aria-current='page']", text: "2")
    end

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

    # Un contrôle qui disparaît entre deux pages déplace la navigation sous l'utilisateur.
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

    # La matrice rôle × habilitation côté liste : ce qui part réellement à la frontière. La
    # règle elle-même est éprouvée dans le spec de la policy.
    context "reading perimeter" do
      it "filters the list on the codes a member is habilitated to" do
        sign_in_member(process_codes: ["CERTDC", "AEC"])
        expect(Portail::HubAPI::Deliveries).to receive(:list)
          # Le reste du hash est éprouvé dans le spec de l'étape FetchList.
          .with(hash_including(data_stream_codes: match_array(["CERTDC", "AEC"])))
          .and_return(build(:portail_delivery_list))

        get "/demarches"

        expect(response).to have_http_status(:success)
      end

      it "filters the list of a local administrator with named habilitations too" do
        sign_in_local_administrator(process_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:list)
          # Le reste du hash est éprouvé dans le spec de l'étape FetchList.
          .with(hash_including(data_stream_codes: ["CERTDC"]))
          .and_return(build(:portail_delivery_list))

        get "/demarches"

        expect(response).to have_http_status(:success)
      end

      it "leaves a local administrator without habilitation unfiltered" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Deliveries).to receive(:list)
          # Le reste du hash est éprouvé dans le spec de l'étape FetchList.
          .with(hash_including(data_stream_codes: []))
          .and_return(build(:portail_delivery_list))

        get "/demarches"

        expect(response).to have_http_status(:success)
      end

      # L'amont est un tiers : s'il ignore le filtre, la ligne hors habilitation ne s'affiche
      # pas, la page reste servie, et l'anomalie part en alerte et sur le canal CSIRT.
      it "hides and reports a delivery the upstream served outside the habilitations" do
        agent = sign_in_member(process_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(
          build(:portail_delivery_list, deliveries: [
            build(:portail_delivery_summary, number: "DGS-CERTDC-0000000000001-01"),
            build(:portail_delivery_summary, id: "hors-perimetre", number: "DGS-AEC-0000000000002-01",
              data_stream_code: "AEC")
          ])
        )
        expect(Sentry).to receive(:capture_message).with(
          a_string_including("Périmètre non respecté par l'amont sur /demarches : 1 élément"),
          level: :warning, extra: hash_including(dropped_ids: ["hors-perimetre"])
        )

        events = capture_semantic_logger_events { get "/demarches" }

        expect(response).to have_http_status(:success)
        expect(Capybara.string(response.body)).to have_text("DGS-CERTDC-0000000000001-01")
        expect(Capybara.string(response.body)).to have_no_text("DGS-AEC-0000000000002-01")
        expect(events).to include(be_a_semantic_logger_event(
          level: :info, message: "Décision d'accès",
          payload_includes: {
            event: "Portail::Access::Decision", outcome: :upstream_mismatch, path: "/demarches",
            dropped_ids: ["hors-perimetre"], membership_id: Membership.find_by!(agent: agent).id,
            ip_address: "127.0.0.1"
          }
        ))
      end
    end
  end

  describe "GET /demarches/:id" do
    let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }

    it "redirects a signed-out visitor to the home page" do
      get "/demarches/#{delivery_id}"

      expect(response).to redirect_to(root_path)
    end

    # Rien n'est bouchonné en deçà de la frontière, et l'amont sert ses champs bancals : une
    # transition à une seule extrémité, un event sans date, une pièce sans taille, pas de
    # demandeur. Chacun a son repli, aucun ne fait tomber la page.
    it "renders a delivery the upstream serves, awkward fields included" do
      sign_in_member
      use_hub_api_fake_client.add_case(build_v2_delivery(
        recipient: upstream_recipient,
        data_package: build_v2_data_package(applicant: nil,
          attachments: [build_v2_attachment(byte_size: nil)]),
        events: [
          build_v2_event(metadata: {to_state: :done}),
          build_v2_event(id: "e2222222-2222-2222-2222-222222222222", created_at: nil)
        ]
      ))

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      page = Capybara.string(response.body)
      expect(page).to have_text("George DUBOIS a modifié le statut : — → Traitée")
      expect(page).to have_text("Sans date")
      expect(Nokogiri::HTML(response.body)
        .xpath("//dt[normalize-space()='Demandeur']/following-sibling::dd[1]").text).to eq("—")
      expect(Nokogiri::HTML(response.body)
        .css("table tbody tr td:nth-child(3)").map { |cell| cell.text.strip }).to eq(["—"])
    end

    it "shows the delivery metadata, applicant included" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("DGS-CERTDC-0000000000001-01")
      expect(Capybara.string(response.body)).to have_text("George DUBOIS")
    end

    # Nokogiri : c'est la valeur rattachée à ce libellé précis qu'on vérifie, donc une position.
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

    # L'amont ne sert aucun binaire : la page le dit, et aucune ligne ne prétend être un lien.
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

    # RGAA : chaque tableau porte un titre, et celui d'un inventaire d'event dit sa provenance.
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

    # Seulement quand l'amont le promet : un changement d'état n'a rien transmis à personne.
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

      # Assertion négative seule : la note absente est tout l'objet de l'exemple.
      expect(Capybara.string(response.body))
        .to have_no_text("Information transmise à la personne concernée.")
    end

    # Le garde-fou de la décision d'afficher `si_comment` : si elle s'inverse, c'est lui qui tombe.
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
      # L'état ouvre le récapitulatif et n'en sort pas.
      expect(page).to have_css("dl.delivery-summary p.fr-badge.fr-badge--success", text: "Traitée")
    end

    # Sans l'enveloppe, dt et dd deviennent deux cellules indépendantes et le libellé se
    # décroche de sa valeur : un défaut que seul l'œil attrape.
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

    # Le quoi et le qui en gras, les dates en gris : tout au même niveau ne mettrait rien en avant.
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

    # Deux rangs : les dates écrites en entier ont besoin d'une demi-largeur.
    it "splits the summary into what is sought and what merely situates it" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:success)

      cells = Nokogiri::HTML(response.body).css("dl.delivery-summary > div").map { |c| c["class"] }
      expect(cells.count { |classes| classes.include?("fr-col-md-4") }).to eq(3)
      expect(cells.count { |classes| classes.include?("fr-col-md-6") }).to eq(2)
    end

    it "renders a not found page when the delivery does not exist" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::NotFound)

      get "/demarches/#{delivery_id}"

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_text("Page introuvable")
    end

    # Une panne au détail est un incident : l'agent est renvoyé avec l'alerte, quelqu'un est réveillé.
    it "sends the agent back with an alert and reports the outage" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::Unavailable)
      expect(Sentry).to receive(:capture_exception)

      get "/demarches/#{delivery_id}"

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("momentanément indisponible")
    end

    # L'identifiant vient de l'URL et finit au journal : des retours à la ligne y forgeraient
    # de fausses lignes.
    it "logs the unknown identifier without letting it forge log lines" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::NotFound)

      events = capture_semantic_logger_events { get "/demarches/evil%0Aforged" }

      line = events.map(&:message).grep(/introuvable/).first
      expect(line).to include('"evil\nforged"')
      expect(line).not_to include("\n")
    end

    # La matrice rôle × habilitation côté détail, le trou que ferme la policy : la liste ne
    # montre pas une démarche hors habilitation, mais son identifiant suffirait à l'ouvrir.
    context "reading perimeter" do
      def delivery_on(code) = build(:portail_delivery, data_stream_code: code)

      # La même page qu'une démarche inexistante : distinguer les deux révélerait l'existence
      # d'une démarche hors périmètre.
      def expect_a_not_found_page
        get "/demarches/#{delivery_id}"

        expect(response).to have_http_status(:not_found)
        expect(Capybara.string(response.body)).to have_text("Page introuvable")
        expect(Capybara.string(response.body)).to have_no_text("DGS-CERTDC-0000000000001-01")
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

      # Seul le journal distingue un refus d'une inexistence, et c'est lui qui laisse voir un
      # agent qui balaie des identifiants. Éprouvé jusqu'à l'appel au logger, sur le canal CSIRT.
      it "refuses a member on a delivery outside their habilitations, and logs the refusal" do
        agent = sign_in_member(process_codes: ["AEC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        events = capture_semantic_logger_events { expect_a_not_found_page }

        membership = Membership.find_by!(agent: agent)
        expect(events).to include(be_a_semantic_logger_event(
          level: :info, message: "Décision d'accès",
          payload_includes: {
            event: "Portail::Access::Decision", outcome: :refused, path: "/demarches/#{delivery_id}",
            agent_id: agent.id, membership_id: membership.id, ip_address: "127.0.0.1"
          }
        ))
      end

      it "refuses a member without any habilitation" do
        sign_in_member(process_codes: [])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_a_not_found_page
      end

      # La requête amont porte déjà l'organisation ; ceci vérifie que l'amont l'a respectée.
      it "refuses a delivery the upstream served for another organisation" do
        sign_in_member(process_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find)
          .and_return(build(:portail_delivery, :of_another_organisation))

        expect_a_not_found_page
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

        expect_a_not_found_page
      end
    end
  end
end
