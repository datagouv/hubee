# frozen_string_literal: true

require "rails_helper"

# Ces exemples bouchonnent Portail::HubAPI et construisent des Portail::Delivery. La traduction
# de la gem est éprouvée dans les specs de la frontière, la chaîne entière dans Cucumber.
RSpec.describe "Portail::Attachments", type: :request do
  let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
  let(:attachment_id) { "a1111111-1111-1111-1111-111111111111" }
  let(:path) { "/demarches/#{delivery_id}/pieces/#{attachment_id}" }

  # Le cas standard du portail : un membre habilité sur le flux de la démarche servie.
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

  # L'inventaire et le contenu se répondent : la pièce annonce la taille des octets qui suivent.
  def piece_of(body, **overrides) = build(:portail_attachment, byte_size: body.bytesize, **overrides)

  def delivery_carrying(body, **overrides) = build(:portail_delivery, attachments: [piece_of(body)], **overrides)

  describe "GET /demarches/:demarche_id/pieces/:id" do
    # Le fichier tel quel, sous son nom d'origine, et jamais dans la page : un type neutre et
    # `attachment`, quel que soit le type que l'amont annonce. Aucun magasin sur le chemin.
    it "serves a received piece under its original filename, as a download, out of any store" do
      sign_in_member
      body = "%PDF-1.7\n\xFF\xFE\x00binaire".b
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_carrying(body))
      expect(Portail::HubAPI::Attachments).to receive(:download)
        .with(delivery_id: delivery_id, id: attachment_id)
        .and_return(body)

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
      attachment = piece_of("octets", filename: "..\\..\\/tmp/rap\r\nport.pdf")
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, attachments: [attachment]))
      expect(Portail::HubAPI::Attachments).to receive(:download).and_return("octets".b)

      get path

      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to eq(
        "attachment; filename=\"rapport.pdf\"; filename*=UTF-8''rapport.pdf"
      )
    end

    it "falls back to a neutral filename when nothing of the original survives" do
      sign_in_member
      attachment = piece_of("octets", filename: "..")
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, attachments: [attachment]))
      expect(Portail::HubAPI::Attachments).to receive(:download).and_return("octets".b)

      get path

      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to eq(
        "attachment; filename=\"piece\"; filename*=UTF-8''piece"
      )
    end

    # Ce que la démarche ne porte pas ne part jamais vers l'amont : la pièce se cherche dans
    # l'inventaire déjà servi.
    it "renders a not found page for a piece the delivery does not carry, without calling the upstream" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(build(:portail_delivery))
      expect(Portail::HubAPI::Attachments).not_to receive(:download)

      get "/demarches/#{delivery_id}/pieces/c3333333-3333-3333-3333-333333333333"

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_text("Page introuvable")
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

      get "/demarches/#{delivery_id}/pieces/e2222222-2222-2222-2222-222222222222"

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

    # L'amont ne sert que des octets, sans rien qui les rattache à la pièce demandée : la taille
    # annoncée par l'inventaire, exacte pour une pièce reçue, est le seul témoin. Un fichier
    # d'une autre taille n'est pas remis, et l'incident est signalé.
    it "refuses a content whose size is not the one the inventory announces, and reports it" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find)
        .and_return(build(:portail_delivery, attachments: [build(:portail_attachment, byte_size: 1024)]))
      expect(Portail::HubAPI::Attachments).to receive(:download).and_return("x" * 1000)
      expect(Rails.error).to receive(:report).with(
        instance_of(Portail::Attachments::Show::VerifyContentSize::UnexpectedSize),
        handled: true, context: {delivery_id: delivery_id, attachment_id: attachment_id, expected: 1024, received: 1000}
      )

      get path

      expect(response).to have_http_status(:service_unavailable)
      expect(Capybara.string(response.body)).to have_text("momentanément indisponible")
      expect(response.body).not_to include("x" * 1000)
    end

    # La matrice rôle × habilitation, sur la pièce et non déduite du détail : c'est ici que les
    # octets partiraient. Le refus tombe avant tout appel de contenu.
    context "reading perimeter" do
      def delivery_on(code) = delivery_carrying("octets", data_stream_code: code)

      # La même page qu'une pièce inexistante : distinguer les deux révélerait l'existence d'une
      # démarche hors périmètre.
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
        sign_in_member(process_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_the_piece_to_be_served
      end

      # Seul le journal distingue un refus d'une inexistence, et c'est lui qui laisse voir un
      # agent qui forge des adresses. Éprouvé jusqu'à l'appel au logger, sur le canal CSIRT.
      it "refuses a member on a piece outside their habilitations, logs and alerts" do
        agent = sign_in_member(process_codes: ["AEC"])
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
        sign_in_member(process_codes: [])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_a_not_found_page
      end

      # La requête amont porte déjà l'organisation ; ceci vérifie que l'amont l'a respectée.
      it "refuses a piece of a delivery the upstream served for another organisation" do
        sign_in_member(process_codes: ["CERTDC"])
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
        sign_in_local_administrator(process_codes: ["CERTDC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_the_piece_to_be_served
      end

      it "refuses a local administrator on a piece outside their habilitations" do
        sign_in_local_administrator(process_codes: ["AEC"])
        expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery_on("CERTDC"))

        expect_a_not_found_page
      end
    end
  end
end
