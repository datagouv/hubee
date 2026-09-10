# frozen_string_literal: true

require "rails_helper"

# Ces exemples bouchonnent Portail::HubAPI et construisent des Portail::Delivery. La traduction
# de la gem est éprouvée dans le spec de la frontière, la chaîne entière dans Cucumber.
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

  describe "GET /demarches/:demarche_id/pieces/:id" do
    it "redirects a signed-out visitor to the home page" do
      get path

      expect(response).to redirect_to(root_path)
    end

    it "serves the piece under its original filename, as a download" do
      sign_in_member
      expect(Portail::HubAPI::Attachments).to receive(:download)
        .and_return(build(:portail_attachment_content))

      get path

      expect(response).to have_http_status(:success)
      expect(response.body).to eq("x" * 1024)
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include('filename="certificat.pdf"')
    end

    # `inline` laisserait le type venu de l'amont décider qu'un fichier s'ouvre dans l'onglet de
    # l'agent. Le seul exemple qui garde cette décision : elle ne se déduit d'aucun autre.
    it "never offers a piece for display inside the page" do
      sign_in_member
      expect(Portail::HubAPI::Attachments).to receive(:download)
        .and_return(build(:portail_attachment_content))

      get path

      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to start_with("attachment;")
    end

    # Le contenu ne doit pas se retrouver en cache partagé ni ressorti par le bouton « précédent ».
    it "keeps the piece out of any store" do
      sign_in_member
      expect(Portail::HubAPI::Attachments).to receive(:download)
        .and_return(build(:portail_attachment_content))

      get path

      expect(response).to have_http_status(:success)
      expect(response.headers["Cache-Control"]).to eq("no-store")
    end

    # Le cœur du lot 3 : l'identité sous laquelle la trace est inscrite, et le fait qu'elle
    # voyage dans le MÊME appel que la remise — la trace est un effet de l'action, pas un second
    # geste qu'un appelant pourrait omettre.
    it "records the download under the identity ProConnect served, not a local one" do
      sign_in_member
      expect(Portail::HubAPI::Attachments).to receive(:download).with(
        delivery_id: delivery_id, id: attachment_id, author: "Alex Martin",
        siret: ProConnectTestHelper::TEST_SIRET,
        insee_code: ProConnectTestHelper::TEST_INSEE_CODE,
        data_stream_codes: ["CERTDC"]
      ).and_return(build(:portail_attachment_content))

      get path

      expect(response).to have_http_status(:success)
      expect(response.body).to eq("x" * 1024)
    end

    # Sa propre page et son propre code : « réessayez » serait faux, rien ne se libérera. Et la
    # demande est recevable — c'est l'état de la démarche qui s'y oppose.
    it "explains the refusal when the delivery history can take no more events" do
      sign_in_member
      expect(Portail::HubAPI::Attachments).to receive(:download)
        .and_raise(Portail::HubAPI::HistoryFull)

      get path

      expect(response).to have_http_status(:conflict)
      expect(Capybara.string(response.body)).to have_text("ne peut pas vous être remise")
      expect(Capybara.string(response.body)).to have_text("historique de cette démarche est saturé")
      expect(response.body).not_to include("x" * 1024)
    end

    # Une pièce absente de la démarche, ou dans un état non livrable : la démarche, elle, est
    # légitimement consultée — c'est une page périmée, pas une tentative.
    it "renders a not found page when the upstream does not serve the piece" do
      sign_in_member
      expect(Portail::HubAPI::Attachments).to receive(:download)
        .and_raise(Portail::HubAPI::AttachmentNotFound)

      get path

      expect(response).to have_http_status(:not_found)
      expect(Capybara.string(response.body)).to have_text("Page introuvable")
    end

    it "renders a service unavailable page when the upstream is failing" do
      sign_in_member
      expect(Portail::HubAPI::Attachments).to receive(:download)
        .and_raise(Portail::HubAPI::Unavailable)

      get path

      expect(response).to have_http_status(:service_unavailable)
      expect(Capybara.string(response.body)).to have_text("momentanément indisponible")
    end

    # Sa propre page : « réessayez dans quelques instants » serait faux pour une pièce purgée, et
    # « introuvable » contredirait l'inventaire que l'agent a sous les yeux. La cause la plus
    # courante n'est pas une panne, c'est un binaire qui n'existe plus.
    it "says the piece could not be retrieved when the upstream serves no bytes" do
      sign_in_member
      expect(Portail::HubAPI::Attachments).to receive(:download)
        .and_raise(Portail::HubAPI::AttachmentUnavailable)

      get path

      expect(response).to have_http_status(:service_unavailable)
      expect(Capybara.string(response.body)).to have_text("n'a pas pu être récupérée")
      expect(Capybara.string(response.body)).to have_no_text("momentanément indisponible")
    end

    # Les identifiants viennent de l'URL et finissent au journal, en champs : le formateur logfmt
    # cite les valeurs, un retour à la ligne n'y forge aucune ligne.
    it "logs both unknown identifiers as fields" do
      sign_in_member
      expect(Portail::HubAPI::Attachments).to receive(:download)
        .and_raise(Portail::HubAPI::AttachmentNotFound)

      events = capture_semantic_logger_events { get path }

      expect(events).to include(be_a_semantic_logger_event(
        level: :info, message: "Pièce introuvable en amont",
        payload_includes: {delivery_id: delivery_id, id: attachment_id, reason: :unknown}
      ))
    end

    # La faille que la gem ne peut pas fermer : `[]` vaut « aucune restriction » en aval, donc un
    # mot-clé perdu en route ouvrirait la lecture à toute l'organisation SANS que rien ne le
    # signale. Ces exemples vérifient que les habilitations voyagent réellement jusqu'à l'appel.
    context "habilitations reaching the upstream call" do
      it "sends the habilitations of a member as the reading perimeter" do
        sign_in_member(process_codes: ["CERTDC", "AEC"])
        expect(Portail::HubAPI::Attachments).to receive(:download).with(
          delivery_id: delivery_id, id: attachment_id, author: "Alex Martin",
          siret: ProConnectTestHelper::TEST_SIRET,
          insee_code: ProConnectTestHelper::TEST_INSEE_CODE,
          data_stream_codes: ["CERTDC", "AEC"]
        ).and_return(build(:portail_attachment_content))

        get path

        expect(response).to have_http_status(:success)
      end

      # L'administrateur local sans habilitation lit toute son organisation : la liste vide est
      # ici une décision, pas un oubli — et c'est bien pour ça que l'exemple ci-dessus existe.
      it "sends an unrestricted perimeter for a local administrator without habilitation" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Attachments).to receive(:download)
          .with(hash_including(data_stream_codes: []))
          # Le hash complet est éprouvé dans l'exemple ci-dessus.
          .and_return(build(:portail_attachment_content))

        get path

        expect(response).to have_http_status(:success)
      end

      it "sends the habilitations of a local administrator who has some" do
        sign_in_local_administrator(process_codes: ["CERTDC"])
        expect(Portail::HubAPI::Attachments).to receive(:download)
          .with(hash_including(data_stream_codes: ["CERTDC"]))
          .and_return(build(:portail_attachment_content))

        get path

        expect(response).to have_http_status(:success)
      end
    end

    # La matrice rôle × habilitation du téléchargement. Elle ne se déduit pas de celle du détail :
    # le flux y est tranché par la policy, ici par la gem — deux mécaniques, deux couvertures.
    context "reading perimeter" do
      # La même page qu'une pièce inexistante : distinguer les deux révélerait l'existence d'un
      # dossier hors périmètre.
      def expect_a_not_found_page
        get path

        expect(response).to have_http_status(:not_found)
        expect(Capybara.string(response.body)).to have_text("Page introuvable")
      end

      # Un membre sans aucune habilitation est refusé AVANT tout appel : transmis en aval, son
      # périmètre vide vaudrait « aucun filtre », donc toute l'organisation.
      it "refuses a member without any habilitation, without calling the upstream" do
        sign_in_member(process_codes: [])
        expect(Portail::HubAPI::Attachments).not_to receive(:download)

        expect_a_not_found_page
      end

      # Le refus prononcé par la gem sur ses quatre causes confondues. Sur cette adresse, qui ne
      # s'atteint qu'après un détail légitimement consulté, il part au CSIRT — là où sur le
      # détail, ouvert au balayage, il ne serait que du bruit.
      it "refuses what the upstream perimeter rejected, logs and alerts" do
        agent = sign_in_member
        expect(Portail::HubAPI::Attachments).to receive(:download)
          .and_raise(Portail::HubAPI::NotFound)
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

      # La ceinture post-réception : la gem a borné, on vérifie qu'elle a tenu. Ces deux exemples
      # décrivent un amont qui rompt son contrat — le portail ne le croit pas sur parole.
      it "refuses a piece of a delivery served for another organisation" do
        sign_in_member
        expect(Portail::HubAPI::Attachments).to receive(:download).and_return(
          build(:portail_attachment_content,
            delivery: build(:portail_delivery, :of_another_organisation))
        )

        expect_a_not_found_page
      end

      it "refuses a piece of a delivery served outside the habilitations" do
        sign_in_member(process_codes: ["AEC"])
        expect(Portail::HubAPI::Attachments).to receive(:download).and_return(
          build(:portail_attachment_content,
            delivery: build(:portail_delivery, data_stream_code: "CERTDC"))
        )

        expect_a_not_found_page
      end

      it "serves a piece of a delivery inside the habilitations of a member" do
        sign_in_member(process_codes: ["CERTDC"])
        expect(Portail::HubAPI::Attachments).to receive(:download).and_return(
          build(:portail_attachment_content,
            delivery: build(:portail_delivery, data_stream_code: "CERTDC"))
        )

        get path

        expect(response).to have_http_status(:success)
        expect(response.body).to eq("x" * 1024)
      end

      it "serves any piece of their organisation to a local administrator without habilitation" do
        sign_in_local_administrator
        expect(Portail::HubAPI::Attachments).to receive(:download).and_return(
          build(:portail_attachment_content,
            delivery: build(:portail_delivery, data_stream_code: "CERTDC"))
        )

        get path

        expect(response).to have_http_status(:success)
        expect(response.body).to eq("x" * 1024)
      end

      it "serves a piece inside the habilitations of a local administrator" do
        sign_in_local_administrator(process_codes: ["CERTDC"])
        expect(Portail::HubAPI::Attachments).to receive(:download).and_return(
          build(:portail_attachment_content,
            delivery: build(:portail_delivery, data_stream_code: "CERTDC"))
        )

        get path

        expect(response).to have_http_status(:success)
        expect(response.body).to eq("x" * 1024)
      end

      it "refuses a local administrator on a piece outside their habilitations" do
        sign_in_local_administrator(process_codes: ["AEC"])
        expect(Portail::HubAPI::Attachments).to receive(:download).and_return(
          build(:portail_attachment_content,
            delivery: build(:portail_delivery, data_stream_code: "CERTDC"))
        )

        expect_a_not_found_page
      end
    end
  end
end
