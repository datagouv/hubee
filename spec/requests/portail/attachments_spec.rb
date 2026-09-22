# frozen_string_literal: true

require "rails_helper"

# Ces exemples bouchonnent Portail::HubAPI et construisent des Portail::Delivery. La traduction
# de la gem est éprouvée dans les specs de la frontière, la chaîne entière dans Cucumber.
RSpec.describe "Portail::Attachments", type: :request do
  let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
  let(:attachment_id) { "a1111111-1111-1111-1111-111111111111" }
  let(:path) { "/teledossiers/#{delivery_id}/pieces/#{attachment_id}" }

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

  describe "GET /teledossiers/:teledossier_id/pieces/:id" do
    # Le fichier tel quel, sous son nom d'origine, et jamais dans la page : un type neutre et
    # `attachment`, quel que soit le type que l'amont annonce. Aucun magasin sur le chemin.
    it "serves a received piece under its original filename, as a download, out of any store" do
      agent = sign_in_member
      link = Membership.find_by!(agent: agent).organization_link
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))
      # La récupération part signée de l'agent de la session — le nom que ProConnect a servi à la
      # connexion — et bornée au périmètre de son rattachement : la chaîne entière, du cookie
      # jusqu'à la frontière.
      expect(Portail::HubAPI::Attachments).to receive(:download)
        .with(delivery_id: delivery_id, id: attachment_id, filename: "certificat.pdf",
          author: "Alex Martin", siret: link.siret, insee_code: link.insee_code)
        .and_return("%PDF-1.7\n\xFF\xFE\x00binaire".b)

      get path

      expect(response).to have_http_status(:success)
      expect(response.body.b).to eq("%PDF-1.7\n\xFF\xFE\x00binaire".b)
      expect(response.media_type).to eq("application/octet-stream")
      expect(response.headers["Content-Disposition"]).to start_with("attachment;")
      expect(response.headers["Content-Disposition"]).to include('filename="certificat.pdf"')
      expect(response.headers["Cache-Control"]).to eq("no-store")
    end

    it "redirects a signed-out visitor to the home page" do
      get path

      expect(response).to redirect_to(root_path)
    end

    # Le nom arrive verbatim du partenaire et finit sur le disque de l'agent : seul le dernier
    # segment survit, antislash compris, sans caractère de contrôle. Le modèle, lui, garde le nom
    # brut : c'est la clé d'appariement de la lecture V1.
    it "hands the agent the last segment of the filename, control characters stripped" do
      sign_in_member
      attachment = build(:portail_attachment, filename: "..\\..\\/tmp/rap\r\nport.pdf")
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, attachments: [attachment]))
      expect(Portail::HubAPI::Attachments).to receive(:download).and_return("octets".b)

      get path

      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to eq(
        "attachment; filename=\"rapport.pdf\"; filename*=UTF-8''rapport.pdf"
      )
    end

    # Un octet nul ferait lever la réduction au dernier segment : il part avant.
    it "survives a null byte in the filename" do
      sign_in_member
      attachment = build(:portail_attachment, filename: "rap\u0000port.pdf")
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, attachments: [attachment]))
      expect(Portail::HubAPI::Attachments).to receive(:download).and_return("octets".b)

      get path

      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to eq(
        "attachment; filename=\"rapport.pdf\"; filename*=UTF-8''rapport.pdf"
      )
    end

    # Une inversion de sens d'écriture ferait lire « rapportexe.pdf » pour un fichier « .exe ».
    it "strips the Unicode formatting characters that could disguise the extension" do
      sign_in_member
      attachment = build(:portail_attachment, filename: "rapport\u202Efdp.exe")
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, attachments: [attachment]))
      expect(Portail::HubAPI::Attachments).to receive(:download).and_return("octets".b)

      get path

      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to eq(
        "attachment; filename=\"rapportfdp.exe\"; filename*=UTF-8''rapportfdp.exe"
      )
    end

    # Le nom d'origine part intact dans la forme UTF-8 de l'en-tête, la seule que lisent les
    # navigateurs actuels ; la forme ASCII est translittérée, un signe inconnu devenant « ? ».
    it "keeps an accented filename intact in the UTF-8 form of the header" do
      sign_in_member
      attachment = build(:portail_attachment, filename: "décision n°1.pdf")
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, attachments: [attachment]))
      expect(Portail::HubAPI::Attachments).to receive(:download).and_return("octets".b)

      get path

      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to eq(
        "attachment; filename=\"decision n%3F1.pdf\"; filename*=UTF-8''d%C3%A9cision%20n%C2%B01.pdf"
      )
    end

    it "falls back to a neutral filename when nothing of the original survives" do
      sign_in_member
      attachment = build(:portail_attachment, filename: "..")
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, attachments: [attachment]))
      expect(Portail::HubAPI::Attachments).to receive(:download).and_return("octets".b)

      get path

      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to eq(
        "attachment; filename=\"piece\"; filename*=UTF-8''piece"
      )
    end

    # Ce que le télédossier ne porte pas ne part jamais vers l'amont : la pièce se cherche dans
    # l'inventaire déjà servi, avant toute autorisation. L'identifiant en champ, avec son motif.
    it "renders a not found page for a piece the delivery does not carry, logged, without calling the upstream" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))
      expect(Portail::HubAPI::Attachments).not_to receive(:download)

      events = capture_semantic_logger_events do
        get "/teledossiers/#{delivery_id}/pieces/c3333333-3333-3333-3333-333333333333"
      end

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_text("Page introuvable")
      expect(events).to include(be_a_semantic_logger_event(
        level: :info, message: "Pièce non livrable",
        payload_includes: {delivery_id: delivery_id, id: "c3333333-3333-3333-3333-333333333333", reason: :unknown}
      ))
    end

    it "renders a not found page for a piece that is not received, without calling the upstream" do
      sign_in_member
      attachment = build(:portail_attachment, state: "pending")
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, attachments: [attachment]))
      expect(Portail::HubAPI::Attachments).not_to receive(:download)

      get path

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_text("Page introuvable")
    end

    # Une pièce ajoutée en cours d'instruction vit sur son événement : hors périmètre, donc
    # introuvable par cette adresse même si l'amont la servirait.
    it "renders a not found page for a piece carried by an event, not by the deposit" do
      sign_in_member
      attachment = build(:portail_attachment, id: "e2222222-2222-2222-2222-222222222222")
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(
        build(:portail_delivery, events: [build(:portail_event, attachments: [attachment])])
      )
      expect(Portail::HubAPI::Attachments).not_to receive(:download)

      get "/teledossiers/#{delivery_id}/pieces/e2222222-2222-2222-2222-222222222222"

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_text("Page introuvable")
    end

    # Les identifiants viennent de l'URL et finissent au journal, en champs, avec le motif.
    it "logs a piece that cannot be delivered as fields" do
      sign_in_member
      attachment = build(:portail_attachment, state: "rejected")
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, attachments: [attachment]))

      events = capture_semantic_logger_events { get path }

      expect(response).to have_http_status(:not_found)
      expect(events).to include(be_a_semantic_logger_event(
        level: :info, message: "Pièce non livrable",
        payload_includes: {delivery_id: delivery_id, id: attachment_id, reason: :not_received}
      ))
    end

    it "renders a not found page when the delivery does not exist" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::NotFound)
      expect(Portail::HubAPI::Attachments).not_to receive(:download)

      get path

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_text("Page introuvable")
    end

    # L'inventaire dit reçue, l'amont dit non : l'inventaire a vieilli entre la page et le clic.
    it "renders a not found page when the upstream no longer serves a piece the inventory carries" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))
      expect(Portail::HubAPI::Attachments).to receive(:download).and_raise(Portail::HubAPI::NotFound)

      get path

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_text("Page introuvable")
    end

    it "renders a service unavailable page when the upstream fails on the delivery" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::Unavailable)

      get path

      expect(response).to have_http_status(:service_unavailable)
      expect(Capybara.string(response.body)).to have_text("momentanément indisponible")
    end

    # Ni introuvable ni en panne : le dossier est plein, la pièce n'est pas remise et réessayer
    # n'y changera rien. Une page à part, parce que l'agent n'a pas la même chose à en conclure.
    it "renders a dedicated page when the history of the delivery is full" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))
      expect(Portail::HubAPI::Attachments).to receive(:download).and_raise(Portail::HubAPI::HistoryFull)

      get path

      expect(response).to have_http_status(:conflict)
      expect(response.body).to include("Cette pièce ne peut pas être remise")
      # L'agent venait d'un télédossier : le retour le ramène là, l'accueil ne vient qu'après.
      page = Capybara.string(response.body)
      expect(page).to have_link("Retour au télédossier", href: "/teledossiers/#{delivery_id}")
      expect(page).to have_link("Retour à l'accueil", href: root_path)
    end

    it "renders a service unavailable page when the upstream fails on the content" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))
      expect(Portail::HubAPI::Attachments).to receive(:download).and_raise(Portail::HubAPI::Unavailable)

      get path

      expect(response).to have_http_status(:service_unavailable)
      expect(Capybara.string(response.body)).to have_text("momentanément indisponible")
    end

    # L'amont n'a pas servi le contenu sans dire pourquoi : l'agent voit la pièce à l'inventaire,
    # lui répondre « introuvable » contredirait son écran. Le mode dégradé existant, sans plus.
    it "renders a service unavailable page when the upstream serves no content for the piece" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))
      expect(Portail::HubAPI::Attachments).to receive(:download)
        .and_raise(Portail::HubAPI::ContentUnavailable)

      get path

      expect(response).to have_http_status(:service_unavailable)
      expect(Capybara.string(response.body)).to have_text("momentanément indisponible")
    end

    # La matrice rôle × habilitation, sur la pièce et non déduite du détail : c'est ici que les
    # octets partiraient. Le refus tombe avant tout appel de contenu.
    context "reading perimeter" do
      def delivery_on(code) = build(:portail_delivery, data_stream_code: code)

      # La même page qu'une pièce inexistante : distinguer les deux révélerait l'existence d'une
      # télédossier hors périmètre.
      def expect_a_not_found_page
        expect(Portail::HubAPI::Attachments).not_to receive(:download)

        get path

        expect(response).to have_http_status(:not_found)
        expect(Capybara.string(response.body)).to have_text("Page introuvable")
        expect(Capybara.string(response.body)).to have_no_text("DGS-CERTDC-0000000000001-01")
      end

      def expect_the_piece_to_be_served
        expect(Portail::HubAPI::Attachments).to receive(:download).and_return("octets".b)

        get path

        expect(response).to have_http_status(:success)
        expect(response.body).to eq("octets")
      end

      it "serves a piece of a delivery on a data stream the member is habilitated to" do
        sign_in_member(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_the_piece_to_be_served
      end

      # Seul le journal distingue un refus d'une inexistence, et c'est lui qui laisse voir un
      # agent qui forge des adresses. Éprouvé jusqu'à l'appel au logger, sur le canal CSIRT.
      it "refuses a member on a piece outside their habilitations, logs and alerts" do
        agent = sign_in_member(data_stream_codes: ["AEC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))
        expect(Sentry).to receive(:capture_message).with(
          "Accès refusé hors périmètre sur #{path}",
          level: :warning, extra: hash_including(agent_id: agent.id)
        )

        events = capture_semantic_logger_events { expect_a_not_found_page }

        membership = Membership.find_by!(agent: agent)
        expect(events).to include(be_a_semantic_logger_event(
          level: :info, message: "Décision d'accès",
          payload_includes: {
            event: "Portail::Access::Refusal", reason: :out_of_perimeter, path: path,
            agent_id: agent.id, membership_id: membership.id, ip_address: "127.0.0.1"
          }
        ))
      end

      it "refuses a member without any habilitation" do
        sign_in_member(data_stream_codes: [])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_a_not_found_page
      end

      # L'accès à une pièce est celui de son télédossier : un état non servi ferme aussi les octets.
      it "refuses a piece of a delivery in a state the portal does not serve" do
        sign_in_member(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find)
          .and_return(build(:portail_delivery, state: "integration_error"))

        expect_a_not_found_page
      end

      # La requête amont porte déjà l'organisation ; ceci vérifie que l'amont l'a respectée.
      it "refuses a piece of a delivery the upstream served for another organisation" do
        sign_in_member(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find)
          .and_return(build(:portail_delivery, :of_another_organisation))

        expect_a_not_found_page
      end

      it "refuses a local administrator on a piece of a delivery served for another organisation" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Deliveries).to receive(:find)
          .and_return(build(:portail_delivery, :of_another_organisation))

        expect_a_not_found_page
      end

      it "serves any piece of their organisation to a local administrator without habilitation" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_the_piece_to_be_served
      end

      it "serves a piece inside the habilitations of a local administrator" do
        sign_in_local_administrator(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_the_piece_to_be_served
      end

      it "refuses a local administrator on a piece outside their habilitations" do
        sign_in_local_administrator(data_stream_codes: ["AEC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_a_not_found_page
      end
    end
  end
end
