# frozen_string_literal: true

require "rails_helper"

# Ces exemples bouchonnent Portail::HubAPI et construisent des Portail::Delivery. La traduction de
# la gem est éprouvée dans les specs de la frontière, la chaîne entière dans Cucumber.
RSpec.describe "Portail::Deliveries::States", type: :request do
  let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
  let(:path) { "/teledossiers/#{delivery_id}/etat" }

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

  # `times: 2` quand l'exemple suit la redirection : le détail relit l'amont, c'est tout l'intérêt
  # de renvoyer l'agent dessus plutôt que d'afficher un état déduit.
  def serve(state: "in_progress", code: "CERTDC", times: 1)
    expect(Portail::HubAPI::Deliveries).to receive(:find).exactly(times).times
      .and_return(build(:portail_delivery, state: state, data_stream_code: code))
  end

  def update_state(state = "done")
    patch path, params: {etat: state}
  end

  def update_state_with_piece(state = "done", piece: pdf_upload)
    patch path, params: {etat: state, piece: piece}
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
      serve(times: 2)
      expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

      update_state("transmitted")
      follow_redirect!

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("n'est pas possible depuis l'état actuel")
    end

    it "refuses a move with no state at all" do
      sign_in_member
      serve(times: 2)
      expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

      patch path, params: {etat: ""}
      follow_redirect!

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("n'est pas possible depuis l'état actuel")
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
        serve(times: 2)
        expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_raise(raised)

        update_state
        follow_redirect!

        expect(response).to have_http_status(:success)
        expect(Capybara.string(response.body)).to have_text(message)
      end
    end

    # Le nom part vers l'émetteur : sans nom, on refuse avant d'écrire, et on le dit à l'agent.
    it "refuses an agent with no name to sign with, and says so" do
      agent = sign_in_member
      agent.update!(first_name: nil, last_name: nil)
      serve(times: 2)
      expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

      update_state
      follow_redirect!

      expect(response).to have_http_status(:success)
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

    context "with a piece" do
      it "publishes the piece, moves the delivery and says both" do
        sign_in_member
        serve(times: 2)
        expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).ordered.and_return(build(:portail_event))
        expect(Portail::HubAPI::Deliveries).to receive(:change_state).ordered.and_return(build(:portail_event))

        update_state_with_piece
        follow_redirect!

        expect(Capybara.string(response.body)).to have_text("L'état du télédossier a été modifié et la pièce transmise")
      end

      it "refuses a format the data stream does not take, before anything leaves" do
        sign_in_member
        serve(times: 2)
        expect(Portail::HubAPI::Deliveries).not_to receive(:reply_with_attachment)
        expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

        update_state_with_piece(piece: pdf_upload(filename: "notes.txt", content_type: "text/plain", bytes: "notes".b))
        follow_redirect!

        expect(Capybara.string(response.body)).to have_text("Ce format de fichier n'est pas accepté")
      end

      {
        Portail::HubAPI::AttachmentContentTypeNotAccepted => "Ce format de fichier n'est pas accepté",
        Portail::HubAPI::AttachmentInfected => "refusé par l'analyse antivirus",
        Portail::HubAPI::AttachmentContentMismatch => "ne correspond pas à son format",
        Portail::HubAPI::Unavailable => "Vérifiez l'historique du télédossier avant de réessayer"
      }.each do |raised, message|
        it "leaves the state alone and says why when the upstream raises #{raised.name.demodulize}" do
          sign_in_member
          serve(times: 2)
          expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).and_raise(raised)
          expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

          update_state_with_piece
          follow_redirect!

          expect(Capybara.string(response.body)).to have_text(message)
        end
      end

      it "says the piece left while the state stayed" do
        sign_in_member
        serve(times: 2)
        expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).and_return(build(:portail_event))
        expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_raise(Portail::HubAPI::EventLimitReached)

        update_state_with_piece
        follow_redirect!

        expect(Capybara.string(response.body))
          .to have_text("La pièce a été transmise, mais l'état du télédossier n'a pas changé")
          .and have_text("ne peut plus enregistrer d'événement")
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
