# frozen_string_literal: true

require "rails_helper"

# Rien n'est bouchonné en deçà de la frontière, sauf ce que le FakeClient ne sait pas produire (le
# contenu non servi, la panne) et un amont qui servirait un télédossier hors périmètre : la trace
# s'observe dans l'historique que le fake tient, et son absence aussi.
RSpec.describe "Portail::Deliveries::Archives", type: :request do
  let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
  let(:path) { "/teledossiers/#{delivery_id}/archive" }

  # L'organisation de l'agent connecté, dans le vocabulaire de la gem : le fake filtre sur ce couple.
  def upstream_recipient
    build_v2_recipient(siret: ProConnectTestHelper::TEST_SIRET, code_insee: ProConnectTestHelper::TEST_INSEE_CODE)
  end

  # Deux pièces reçues, une en attente : l'archive ne doit contenir que les premières.
  def serve_delivery(client = use_hub_api_fake_client, **overrides)
    client.add_case(build_v2_delivery(id: delivery_id, recipient: upstream_recipient,
      data_package: build_v2_data_package(attachments: [
        build_v2_attachment(id: "a1111111-1111-1111-1111-111111111111", filename: "certificat.pdf"),
        build_v2_attachment(id: "b2222222-2222-2222-2222-222222222222", filename: "flux.xml"),
        build_v2_attachment(id: "c3333333-3333-3333-3333-333333333333", filename: "acte.pdf", state: :pending)
      ]), **overrides))
  end

  def history(client)
    HubApiV1::V2::Delivery.find(id: delivery_id, siret: ProConnectTestHelper::TEST_SIRET,
      code_insee: ProConnectTestHelper::TEST_INSEE_CODE, client: client).events
  end

  def content_requests(client)
    client.requests.select { |request| request.path.include?("/attachments/") }
  end

  def events_requests(client) = client.requests_to("#{HubApiV1::Case::PATH}/#{delivery_id}/events")

  # rubyzip relit les noms en binaire, drapeau UTF-8 ou non.
  def entries(body)
    Zip::File.open_buffer(StringIO.new(body)).entries
      .map { |entry| [entry.name.dup.force_encoding(Encoding::UTF_8), entry.get_input_stream.read.b] }
  end

  describe "GET /teledossiers/:teledossier_id/archive" do
    # L'archive entière, sous le nom V1, jamais dans la page, hors de tout magasin. La trace part
    # signée de l'agent de la session, le nom que ProConnect a servi à la connexion.
    it "hands over a zip of the received pieces, named after the click and the number, traced once" do
      sign_in_member
      client = serve_delivery
      client.add_attachment_content(attachment_id: "a1111111-1111-1111-1111-111111111111",
        body: "%PDF-1.7\n\xFF\xFE\x00binaire".b)
      client.add_attachment_content(attachment_id: "b2222222-2222-2222-2222-222222222222", body: "<xml/>".b)
      previous_events = history(client)

      travel_to(Time.utc(2026, 9, 23, 12, 5)) { get path }

      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Type"]).to eq("application/zip")
      expect(response.headers["Content-Disposition"]).to eq(
        "attachment; filename=\"20260923-14.05_DGS-CERTDC-0000000000001-01.zip\"; " \
        "filename*=UTF-8''20260923-14.05_DGS-CERTDC-0000000000001-01.zip"
      )
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(response.headers["Content-Length"]).to eq(response.body.bytesize.to_s)
      expect(entries(response.body)).to eq([
        ["20260923-14.05_DGS-CERTDC-0000000000001-01/certificat.pdf", "%PDF-1.7\n\xFF\xFE\x00binaire".b],
        ["20260923-14.05_DGS-CERTDC-0000000000001-01/flux.xml", "<xml/>".b]
      ])
      expect(history(client) - previous_events).to contain_exactly(have_attributes(
        event_type: :"attachment.all_downloaded", content: "20260923-14.05_DGS-CERTDC-0000000000001-01.zip",
        author: "Alex MARTIN"
      ))
    end

    # Le contenu ne fait que traverser : l'archive ne survit pas à son envoi.
    it "leaves no archive behind once it is sent" do
      sign_in_member
      serve_delivery
      paths = watch_tempfile_paths

      get path

      expect(response).to have_http_status(:success)
      expect(entries(response.body).size).to eq(2)
      expect(paths.size).to eq(1)
      expect(File.exist?(paths.first)).to be(false)
    end

    # Une erreur après l'action, ici dans un `after_action` : le corps n'est jamais fermé, Rack
    # supprime l'archive quand même.
    it "leaves no archive behind when an error occurs after the action" do
      sign_in_member
      serve_delivery
      paths = watch_tempfile_paths
      expect_any_instance_of(Portail::Deliveries::ArchivesController).to receive(:verify_authorized)
        .and_raise(RuntimeError, "after the action")

      expect { get path }.to raise_error(RuntimeError, "after the action")
      expect(paths.size).to eq(1)
      expect(File.exist?(paths.first)).to be(false)
    end

    # Une requête HEAD ne remet rien : assembler l'archive la tracerait pour un agent qui ne la
    # reçoit pas.
    it "refuses a HEAD request without reading the delivery nor any piece nor writing any trace" do
      sign_in_member
      client = serve_delivery
      expect(Tempfile).not_to receive(:new)

      head path

      expect(response).to have_http_status(:method_not_allowed)
      expect(response.headers["Allow"]).to eq("GET")
      expect(response.headers["Content-Disposition"]).to be_nil
      expect(client.requests).to be_empty
    end

    it "redirects a signed-out visitor to the home page" do
      get path

      expect(response).to redirect_to(root_path)
    end

    it "renders a not found page for a delivery without any received piece, without asking for any content" do
      sign_in_member
      client = use_hub_api_fake_client
      client.add_case(build_v2_delivery(id: delivery_id, recipient: upstream_recipient,
        data_package: build_v2_data_package(attachments: [build_v2_attachment(state: :pending)])))

      get path

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_text("Page introuvable")
      expect(content_requests(client)).to be_empty
      expect(events_requests(client)).to be_empty
    end

    it "renders a not found page when the delivery does not exist" do
      sign_in_member
      client = use_hub_api_fake_client

      get path

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_text("Page introuvable")
      expect(content_requests(client)).to be_empty
      expect(events_requests(client)).to be_empty
    end

    it "renders the same not found page for a malformed identifier, without reporting" do
      sign_in_member
      client = use_hub_api_fake_client
      expect(Rails.error).not_to receive(:report)

      get "/teledossiers/pas-un-identifiant/archive"

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_text("Page introuvable")
      expect(content_requests(client)).to be_empty
      expect(client.requests_to("#{HubApiV1::Case::PATH}/pas-un-identifiant/events")).to be_empty
    end

    it "renders a service unavailable page, untraced, when the upstream fails on the delivery" do
      sign_in_member
      client = use_hub_api_fake_client
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::Unavailable)

      get path

      expect(response).to have_http_status(:service_unavailable)
      expect(Capybara.string(response.body)).to have_text("momentanément indisponible")
      expect(content_requests(client)).to be_empty
      expect(events_requests(client)).to be_empty
    end

    it "sends an agent whose account carries no name back to the delivery, asking nothing of the upstream" do
      agent = sign_in_member
      agent.update!(first_name: nil, last_name: nil)
      client = serve_delivery

      get path

      expect(response).to redirect_to("/teledossiers/#{delivery_id}")
      expect(flash[:alert]).to eq("Votre compte ne porte ni prénom ni nom. Contactez le support : " \
        "l'émetteur du dossier doit pouvoir identifier qui a retiré les pièces.")
      expect(content_requests(client)).to be_empty
      expect(events_requests(client)).to be_empty
    end

    # Pas d'archive partielle : une pièce reçue que l'amont ne sert pas, et l'agent ne reçoit rien.
    it "renders the dedicated page, untraced, when the upstream serves no content for a piece" do
      sign_in_member
      client = serve_delivery
      stub_hub_api_v2_attachment_downloaded("a1111111-1111-1111-1111-111111111111")
      stub_hub_api_v2_attachment_unavailable("b2222222-2222-2222-2222-222222222222")
      paths = watch_tempfile_paths

      get path

      expect(response).to have_http_status(:service_unavailable)
      expect(response.media_type).to eq("text/html")
      expect(response.headers["Content-Disposition"]).to be_nil
      page = Capybara.string(response.body)
      expect(page).to have_title("Archive non remise — HubEE", exact: true)
      expect(page).to have_css("h1", exact_text: "L'archive n'a pas pu être remise")
      expect(page).to have_css(".fr-text--lead", exact_text: "L'une des pièces reçues n'est pas disponible : " \
        "l'archive n'est remise que si elle les contient toutes. Réessayez plus tard ; si le problème persiste, " \
        "contactez le support.")
      expect(page).to have_link("Retour au télédossier", href: "/teledossiers/#{delivery_id}")
      expect(events_requests(client)).to be_empty
      expect(paths.size).to eq(1)
      expect(File.exist?(paths.first)).to be(false)
    end

    it "renders the dedicated page, untraced, when the history of the delivery is full" do
      sign_in_member
      client = serve_delivery
      client.saturate_case(delivery_id)
      full = history(client)
      paths = watch_tempfile_paths

      get path

      expect(response).to have_http_status(:conflict)
      expect(response.media_type).to eq("text/html")
      expect(response.headers["Content-Disposition"]).to be_nil
      page = Capybara.string(response.body)
      expect(page).to have_title("Archive non remise — HubEE", exact: true)
      expect(page).to have_css("h1", exact_text: "L'archive ne peut pas être remise")
      expect(page).to have_css(".fr-text--lead",
        exact_text: "Ce télédossier ne peut plus enregistrer d'événement. Contactez le support.")
      expect(page).to have_link("Retour au télédossier", href: "/teledossiers/#{delivery_id}")
      expect(page).to have_link("Retour à l'accueil", href: root_path)
      expect(history(client)).to eq(full)
      expect(paths.size).to eq(1)
      expect(File.exist?(paths.first)).to be(false)
    end

    it "renders a service unavailable page, untraced, when the upstream fails on a content" do
      sign_in_member
      client = serve_delivery
      stub_hub_api_v2_attachment_error("a1111111-1111-1111-1111-111111111111")
      paths = watch_tempfile_paths

      get path

      expect(response).to have_http_status(:service_unavailable)
      expect(response.media_type).to eq("text/html")
      expect(response.headers["Content-Disposition"]).to be_nil
      expect(Capybara.string(response.body)).to have_text("momentanément indisponible")
      expect(events_requests(client)).to be_empty
      expect(paths.size).to eq(1)
      expect(File.exist?(paths.first)).to be(false)
    end

    # La matrice rôle × habilitation, sur l'archive et non déduite du détail : c'est ici que les
    # octets partiraient. Le refus tombe avant tout appel de contenu, et rien n'est tracé.
    context "reading perimeter" do
      # La même page qu'un télédossier inexistant : distinguer les deux révélerait son existence.
      def expect_a_not_found_page(client)
        get path

        expect(response).to have_http_status(:not_found)
        expect(Capybara.string(response.body)).to have_text("Page introuvable")
        expect(content_requests(client)).to be_empty
        expect(events_requests(client)).to be_empty
      end

      def expect_the_archive_to_be_served
        get path

        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq("application/zip")
        expect(entries(response.body).size).to eq(2)
      end

      it "serves the archive of a delivery on a data stream the member is habilitated to" do
        sign_in_member(data_stream_codes: ["CERTDC"])
        serve_delivery

        expect_the_archive_to_be_served
      end

      # Seul le journal distingue un refus d'une inexistence : il laisse voir un agent qui forge
      # des adresses, sur le canal CSIRT.
      it "refuses a member on a delivery outside their habilitations, logs and alerts" do
        agent = sign_in_member(data_stream_codes: ["AEC"])
        client = serve_delivery
        expect(Sentry).to receive(:capture_message).with(
          "Accès refusé hors périmètre sur #{path}", level: :warning, extra: hash_including(agent_id: agent.id)
        )

        events = capture_semantic_logger_events { expect_a_not_found_page(client) }

        expect(events).to include(be_a_semantic_logger_event(
          level: :info, message: "Décision d'accès",
          payload_includes: {event: "Portail::Access::Refusal", reason: :out_of_perimeter, path: path,
                             agent_id: agent.id}
        ))
      end

      it "refuses a member without any habilitation" do
        sign_in_member(data_stream_codes: [])

        expect_a_not_found_page(serve_delivery)
      end

      it "serves any delivery of their organisation to a local administrator without habilitation" do
        sign_in_local_administrator
        serve_delivery

        expect_the_archive_to_be_served
      end

      it "serves the archive inside the habilitations of a local administrator" do
        sign_in_local_administrator(data_stream_codes: ["CERTDC"])
        serve_delivery

        expect_the_archive_to_be_served
      end

      it "refuses a local administrator on a delivery outside their habilitations" do
        sign_in_local_administrator(data_stream_codes: ["AEC"])

        expect_a_not_found_page(serve_delivery)
      end

      it "refuses a delivery in a state the portal does not serve" do
        sign_in_member(data_stream_codes: ["CERTDC"])

        expect_a_not_found_page(serve_delivery(state: :integration_error))
      end

      # La requête amont porte déjà l'organisation ; ceci vérifie que l'amont l'a respectée, pour
      # les deux rôles.
      it "refuses a member on a delivery the upstream served for another organisation" do
        sign_in_member(data_stream_codes: ["CERTDC"])
        client = use_hub_api_fake_client
        expect(Portail::HubAPI::Deliveries).to receive(:find)
          .and_return(build(:portail_delivery, :of_another_organisation))

        expect_a_not_found_page(client)
      end

      it "refuses a local administrator on a delivery the upstream served for another organisation" do
        sign_in_local_administrator
        client = use_hub_api_fake_client
        expect(Portail::HubAPI::Deliveries).to receive(:find)
          .and_return(build(:portail_delivery, :of_another_organisation))

        expect_a_not_found_page(client)
      end
    end
  end
end
