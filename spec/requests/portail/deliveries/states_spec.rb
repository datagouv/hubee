# frozen_string_literal: true

require "rails_helper"

# Ces exemples bouchonnent Portail::HubAPI et construisent des Portail::Delivery. La traduction de
# la gem est éprouvée dans les specs de la frontière, la chaîne entière dans Cucumber.
RSpec.describe "Portail::Deliveries::States", type: :request do
  let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
  let(:path) { "/teledossiers/#{delivery_id}/etat" }

  # `times: 2` quand l'exemple suit la redirection d'un succès : le détail relit l'amont. Un refus
  # rend le détail tel que lu en tête de requête.
  def serve(state: "in_progress", code: "CERTDC", times: 1)
    expect(Portail::HubAPI::Deliveries).to receive(:find).exactly(times).times
      .and_return(build(:portail_delivery, :retrieved, state: state, data_stream_code: code))
  end

  def update_state(state = "done", message: nil)
    patch path, params: {etat: state, message: message}.compact
  end

  def update_state_with_piece(state = "done", piece: pdf_upload, message: nil)
    patch path, params: {etat: state, piece: piece, message: message}.compact
  end

  # La validation de la cible lit le flux du télédossier, permissif ici : les refus du flux sont
  # éprouvés sur l'organizer.
  before do
    stub_organisation_subscriptions
    stub_data_stream
  end

  describe "PATCH /teledossiers/:teledossier_id/etat" do
    it "moves the delivery and tells the agent so on the detail" do
      sign_in_member
      serve(times: 2)
      expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_return(build(:portail_event))

      update_state

      # 303 : la convention Rails après écriture, et la seule qui ne laisse aucune ambiguïté sur
      # la méthode rejouée.
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to("/teledossiers/#{delivery_id}")
      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("L'état du télédossier a été modifié")
    end

    it "refuses a move the table does not offer, without calling the upstream" do
      sign_in_member
      serve
      expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

      update_state("transmitted")

      expect(response).to have_http_status(:unprocessable_content)
      expect(Capybara.string(response.body)).to have_text("n'est plus possible")
    end

    # Un collègue l'a marqué reçu entre l'affichage et le clic : la table refuse, rien n'est réécrit.
    it "refuses to mark received a delivery already received meanwhile, and says why it may be" do
      sign_in_member
      serve(state: "acknowledged")
      expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

      update_state("acknowledged")

      expect(response).to have_http_status(:unprocessable_content)
      expect(Capybara.string(response.body)).to have_text("a peut-être changé d'état entre-temps")
    end

    it "refuses a decision on a delivery never retrieved, naming the target state, without calling the upstream" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).once
        .and_return(build(:portail_delivery, state: "in_progress"))
      expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

      update_state("done")

      expect(response).to have_http_status(:unprocessable_content)
      expect(Capybara.string(response.body))
        .to have_css(".fr-alert--error p", exact_text: "Ce changement d'état n'est pas encore possible : téléchargez d'abord " \
          "au moins une pièce jointe du télédossier pour le passer au statut « Traité ».")
    end

    it "records a complements request on a delivery never retrieved" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).twice
        .and_return(build(:portail_delivery, state: "in_progress"))
      expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_return(build(:portail_event))

      update_state("awaiting_attachments")
      follow_redirect!

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("L'état du télédossier a été modifié")
    end

    it "refuses a move with no state at all" do
      sign_in_member
      serve
      expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

      patch path, params: {etat: ""}

      expect(response).to have_http_status(:unprocessable_content)
      expect(Capybara.string(response.body)).to have_text("n'est plus possible")
    end

    it "refuses a move the data stream withholds, naming the target state, without calling the upstream" do
      sign_in_member
      serve
      stub_data_stream(build(:portail_data_stream, allowed_states: %w[transmitted acknowledged in_progress awaiting_attachments done closed]))
      expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

      update_state("refused")

      expect(response).to have_http_status(:unprocessable_content)
      expect(Capybara.string(response.body))
        .to have_css(".fr-alert--error p", exact_text: "Ce flux n'autorise pas le statut « Refusé ».")
    end

    it "refuses a move to an unknown state without failing on its label" do
      sign_in_member
      serve
      expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

      update_state("archived")

      expect(response).to have_http_status(:unprocessable_content)
      expect(Capybara.string(response.body)).to have_text("n'est plus possible")
    end

    {
      Portail::HubAPI::EventLimitReached => "ne peut plus enregistrer d'événement",
      Portail::HubAPI::AwaitingAttachmentsNotAllowed => "n'autorise pas l'attente de compléments",
      Portail::HubAPI::NotFound => "n'est plus accessible",
      Portail::HubAPI::InvalidRequest => "n'a pas pu être enregistré",
      Portail::HubAPI::Unavailable => "momentanément indisponible"
    }.each do |raised, message|
      it "shows a message rather than an error page when the upstream raises #{raised.name.demodulize}" do
        sign_in_member
        serve
        expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_raise(raised)

        update_state

        expect(response).to have_http_status(:unprocessable_content)
        expect(Capybara.string(response.body)).to have_text(message)
      end
    end

    # Le nom part vers l'émetteur : sans nom, on refuse avant d'écrire, et on le dit à l'agent.
    it "refuses an agent with no name to sign with, and says so" do
      agent = sign_in_member
      agent.update!(first_name: nil, last_name: nil)
      serve
      expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

      update_state

      expect(response).to have_http_status(:unprocessable_content)
      expect(Capybara.string(response.body)).to have_text("ne porte ni prénom ni nom")
    end

    it "shows the degraded page when the delivery cannot be read at all" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::Unavailable)

      update_state

      expect(response).to have_http_status(:service_unavailable)
    end

    it "answers not found when the upstream serves no such delivery" do
      sign_in_member
      expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::NotFound)

      update_state

      expect(response).to have_http_status(:not_found)
    end

    # hash_including : seul le message varie ici, le contrat complet est asserté sur WriteState et
    # sur HubAPI::Deliveries.
    context "with a message" do
      it "sends what the agent wrote along with the move" do
        sign_in_member
        serve(times: 2)
        expect(Portail::HubAPI::Deliveries).to receive(:change_state)
          .with(hash_including(message: "Pièce illisible, merci de la renvoyer."))
          .and_return(build(:portail_event))

        update_state(message: "  Pièce illisible, merci de la renvoyer.  ")
        follow_redirect!

        expect(response).to have_http_status(:success)
        expect(Capybara.string(response.body)).to have_text("L'état du télédossier a été modifié")
      end

      # Des blancs ne sont pas un message : rien à refuser, même sur un flux qui n'en prend pas.
      it "sends no message when the agent wrote only blanks" do
        sign_in_member
        serve
        stub_data_stream(build(:portail_data_stream, v1: build(:portail_data_stream_v1_rules, :without_message)))
        expect(Portail::HubAPI::Deliveries).to receive(:change_state)
          .with(hash_including(message: nil)).and_return(build(:portail_event))

        update_state(message: "  \r\n ")

        expect(response).to have_http_status(:see_other)
      end

      it "keeps the message in the form when the move fails, to try again" do
        sign_in_member
        serve
        expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_raise(Portail::HubAPI::Unavailable)

        update_state(message: "Pièce illisible")

        expect(response).to have_http_status(:unprocessable_content)
        expect(Capybara.string(response.body))
          .to have_field("Message à la personne concernée (facultatif)", with: "Pièce illisible")
      end

      it "refuses a message the data stream does not take, before anything leaves" do
        sign_in_member
        serve
        stub_data_stream(build(:portail_data_stream, v1: build(:portail_data_stream_v1_rules, :without_message)))
        expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

        update_state(message: "Pièce illisible")

        expect(response).to have_http_status(:unprocessable_content)
        expect(Capybara.string(response.body)).to have_css(".fr-alert--error p",
          exact_text: "Ce flux n'accepte pas de message avec le changement d'état. Rien n'a été transmis.")
      end

      it "refuses a message over 500 characters, before anything leaves" do
        sign_in_member
        serve
        expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

        update_state(message: "a" * 501)

        expect(response).to have_http_status(:unprocessable_content)
        expect(Capybara.string(response.body))
          .to have_css(".fr-alert--error p", exact_text: "Le message dépasse 500 caractères. Rien n'a été transmis.")
      end

      # En vraie requête, `message[texte]=…` arrive en ActionController::Parameters, pas en Hash.
      it "carries no message from a nested form" do
        sign_in_member
        serve
        expect(Portail::HubAPI::Deliveries).to receive(:change_state)
          .with(hash_including(message: nil)).and_return(build(:portail_event))

        patch path, params: {etat: "done", message: {texte: "Pièce illisible"}}

        expect(response).to have_http_status(:see_other)
      end

      it "neither publishes the piece nor moves when the message is refused" do
        sign_in_member
        serve
        expect(Portail::HubAPI::Deliveries).not_to receive(:reply_with_attachment)
        expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

        update_state_with_piece(message: "a" * 501)

        expect(response).to have_http_status(:unprocessable_content)
        expect(Capybara.string(response.body)).to have_text("Le message dépasse 500 caractères")
      end
    end

    context "with a piece" do
      it "publishes the piece, moves the delivery with the message and says both" do
        sign_in_member
        serve(times: 2)
        expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).ordered.and_return(build(:portail_event))
        expect(Portail::HubAPI::Deliveries).to receive(:change_state).ordered
          .with(hash_including(message: "Décision jointe")).and_return(build(:portail_event))

        update_state_with_piece(message: "Décision jointe")
        follow_redirect!

        expect(response).to have_http_status(:success)
        expect(Capybara.string(response.body)).to have_text("L'état du télédossier a été modifié et la pièce transmise")
      end

      it "refuses a format the data stream does not take, before anything leaves" do
        sign_in_member
        serve
        expect(Portail::HubAPI::Deliveries).not_to receive(:reply_with_attachment)
        expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

        update_state_with_piece(piece: pdf_upload(filename: "notes.txt", content_type: "text/plain", bytes: "notes".b))

        expect(response).to have_http_status(:unprocessable_content)
        expect(Capybara.string(response.body)).to have_text("Ce format de fichier n'est pas accepté")
      end

      it "refuses a decision on a delivery never retrieved, naming the target state, before anything leaves" do
        sign_in_member
        expect(Portail::HubAPI::Deliveries).to receive(:find).once
          .and_return(build(:portail_delivery, state: "in_progress"))
        expect(Portail::HubAPI::Deliveries).not_to receive(:reply_with_attachment)
        expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

        update_state_with_piece("done")

        expect(response).to have_http_status(:unprocessable_content)
        expect(Capybara.string(response.body))
          .to have_css(".fr-alert--error p", exact_text: "Ce changement d'état n'est pas encore possible : téléchargez d'abord " \
            "au moins une pièce jointe du télédossier pour le passer au statut « Traité ».")
      end

      # Refus du portail lui-même, dits avant tout envoi : chacun a son libellé.
      {
        "an empty file" => {piece: {bytes: "".b}, message: "Ce fichier est vide"},
        "a name longer than the upstream stores" => {piece: {filename: "#{"a" * 252}.pdf"}, message: "Le nom de ce fichier est vide ou trop long"}
      }.each do |refused, setup|
        it "refuses #{refused} before anything leaves" do
          sign_in_member
          serve
          expect(Portail::HubAPI::Deliveries).not_to receive(:reply_with_attachment)
          expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

          update_state_with_piece(piece: pdf_upload(**setup[:piece]))

          expect(response).to have_http_status(:unprocessable_content)
          expect(Capybara.string(response.body)).to have_text(setup[:message])
        end
      end

      {
        Portail::HubAPI::AttachmentContentTypeNotAccepted => "Ce format de fichier n'est pas accepté",
        Portail::HubAPI::AttachmentInfected => "refusé par l'analyse antivirus",
        Portail::HubAPI::AttachmentContentMismatch => "ne correspond pas à son format",
        Portail::HubAPI::Unavailable => "Vérifiez l'historique du télédossier avant de réessayer"
      }.each do |raised, message|
        it "leaves the state alone and says why when the upstream raises #{raised.name.demodulize}" do
          sign_in_member
          serve
          expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).and_raise(raised)
          expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

          update_state_with_piece

          expect(response).to have_http_status(:unprocessable_content)
          expect(Capybara.string(response.body)).to have_text(message)
        end
      end

      it "says the piece left while the state stayed" do
        sign_in_member
        serve
        expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).and_return(build(:portail_event))
        expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_raise(Portail::HubAPI::EventLimitReached)

        update_state_with_piece

        expect(response).to have_http_status(:unprocessable_content)
        expect(Capybara.string(response.body))
          .to have_text("La pièce a été transmise, mais l'état du télédossier n'a pas changé")
          .and have_text("ne peut plus enregistrer d'événement")
      end

      # Le message voyage avec l'état : resté en route, il doit être ressaisi, sinon la pièce
      # arriverait seule.
      it "keeps the message in the form when the piece left while the state stayed" do
        sign_in_member
        serve
        expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).and_return(build(:portail_event))
        expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_raise(Portail::HubAPI::EventLimitReached)

        update_state_with_piece(message: "Décision jointe")

        expect(response).to have_http_status(:unprocessable_content)
        page = Capybara.string(response.body)
        expect(page).to have_text("Vous pouvez relancer le seul changement d'état.")
        expect(page).to have_field("Message à la personne concernée (facultatif)", with: "Décision jointe")
      end
    end

    # Rejouer un PATCH après connexion n'aurait pas de sens : le portail ne le mémorise pas.
    it "sends a visitor without a session back to the home page" do
      expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

      update_state

      expect(response).to redirect_to(root_path)
    end

    # Aucune combinaison ne se déduit d'une autre, écriture comprise. C'est le seul point où
    # l'habilitation est appliquée en écriture : l'étape de lecture ne porte aucune policy.
    context "writing perimeter" do
      def expect_a_not_found_page
        expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

        update_state

        expect(response).to have_http_status(:not_found)
      end

      def expect_the_move_to_go_through
        expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_return(build(:portail_event))

        update_state

        expect(response).to redirect_to("/teledossiers/#{delivery_id}")
      end

      it "lets a habilitated member move a delivery of their organisation" do
        sign_in_member
        serve

        expect_the_move_to_go_through
      end

      it "refuses a member outside their habilitations" do
        sign_in_member(data_stream_codes: ["AUTRE"])
        serve

        expect_a_not_found_page
      end

      it "refuses a member without any habilitation" do
        sign_in_member(data_stream_codes: [])
        serve

        expect_a_not_found_page
      end

      it "lets a local administrator without habilitation move a delivery" do
        sign_in_local_administrator
        serve

        expect_the_move_to_go_through
      end

      it "lets a local administrator habilitated on the data stream move a delivery" do
        sign_in_local_administrator(data_stream_codes: ["CERTDC"])
        serve

        expect_the_move_to_go_through
      end

      it "refuses a local administrator outside their habilitations" do
        sign_in_local_administrator(data_stream_codes: ["AUTRE"])
        serve

        expect_a_not_found_page
      end

      it "refuses a delivery of another organisation" do
        sign_in_member
        expect(Portail::HubAPI::Deliveries).to receive(:find)
          .and_return(build(:portail_delivery, :of_another_organisation, state: "in_progress"))

        expect_a_not_found_page
      end

      it "refuses a delivery in a state the portal does not serve" do
        sign_in_member
        serve(state: "integration_error")

        expect_a_not_found_page
      end

      it "reports the refusal to the security channel" do
        agent = sign_in_member(data_stream_codes: ["AUTRE"])
        membership = Membership.find_by!(agent: agent)
        serve

        events = capture_semantic_logger_events { update_state }

        expect(events).to include(be_a_semantic_logger_event(
          level: :info, message: "Décision d'accès",
          payload_includes: {event: "Portail::Access::Refusal", reason: :out_of_perimeter,
                             path: path, agent_id: agent.id, membership_id: membership.id}
        ))
      end
    end

    # Aucune combinaison ne se déduit d'une autre : la pièce a sa propre matrice.
    context "writing perimeter with a piece" do
      def expect_a_not_found_page
        expect(Portail::HubAPI::Deliveries).not_to receive(:reply_with_attachment)

        update_state_with_piece

        expect(response).to have_http_status(:not_found)
      end

      def expect_the_piece_to_go_through
        expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).and_return(build(:portail_event))
        expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_return(build(:portail_event))

        update_state_with_piece

        expect(response).to redirect_to("/teledossiers/#{delivery_id}")
      end

      it "lets a habilitated member join a piece" do
        sign_in_member
        serve

        expect_the_piece_to_go_through
      end

      it "refuses a member outside their habilitations" do
        sign_in_member(data_stream_codes: ["AUTRE"])
        serve

        expect_a_not_found_page
      end

      it "refuses a member without any habilitation" do
        sign_in_member(data_stream_codes: [])
        serve

        expect_a_not_found_page
      end

      it "lets a local administrator without habilitation join a piece" do
        sign_in_local_administrator
        serve

        expect_the_piece_to_go_through
      end

      it "lets a local administrator habilitated on the data stream join a piece" do
        sign_in_local_administrator(data_stream_codes: ["CERTDC"])
        serve

        expect_the_piece_to_go_through
      end

      it "refuses a local administrator outside their habilitations" do
        sign_in_local_administrator(data_stream_codes: ["AUTRE"])
        serve

        expect_a_not_found_page
      end

      it "refuses a delivery of another organisation" do
        sign_in_member
        expect(Portail::HubAPI::Deliveries).to receive(:find)
          .and_return(build(:portail_delivery, :of_another_organisation, state: "in_progress"))

        expect_a_not_found_page
      end
    end
  end
end
