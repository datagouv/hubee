# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Attachments::Show::FetchContent do
  let(:delivery) { build(:portail_delivery) }
  let(:attachment) { build(:portail_attachment) }
  let(:agent) { create(:agent, first_name: "Alice", last_name: "Martin", email: "alice@exemple.gouv.fr") }
  let(:membership) do
    build(:membership, agent: agent,
      organization_link: build(:organization_link, siret: "12345678901234", insee_code: "75056"))
  end

  def fetch(attachment: self.attachment, agent: self.agent)
    described_class.call(delivery: delivery, attachment: attachment, membership: membership, agent: agent)
  end

  # Les identifiants viennent de l'inventaire servi, jamais de l'URL. L'auteur vient de la session,
  # jamais d'un paramètre de requête : aucun agent ne peut tracer sous une autre identité.
  it "fetches the content of the piece within its delivery, signed by the agent of the session" do
    expect(Portail::HubAPI::Attachments).to receive(:download).with(
      delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", id: "a1111111-1111-1111-1111-111111111111",
      filename: "certificat.pdf", author: "Alice Martin", siret: "12345678901234", insee_code: "75056"
    ).and_return("octets".b)

    result = fetch

    expect(result).to be_success
    expect(result.body).to eq("octets".b)
  end

  # `hash_including` dans les trois exemples qui suivent : le hash complet est éprouvé par
  # l'exemple ci-dessus, et chacun n'isole que la dimension qu'il fait varier.
  #
  # Prénom et nom sont nullables en base, seule l'adresse est obligatoire. Le partenaire déposant
  # lit le même historique : l'adresse d'un agent sans nom lui est donc visible, et c'est assumé.
  it "signs the trace with the email address of an agent without a name" do
    nameless = create(:agent, first_name: nil, last_name: nil, email: "sans.nom@exemple.gouv.fr")
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .with(hash_including(author: "sans.nom@exemple.gouv.fr")).and_return("octets".b)

    expect(fetch(agent: nameless)).to be_success
  end

  # La trace porte le nom BRUT : la lecture V1 apparie l'événement à la pièce par égalité stricte.
  # Le nom assaini reste réservé au fichier posé sur le disque de l'agent.
  it "traces the filename as the partner wrote it, never the sanitised one" do
    raw = build(:portail_attachment, filename: "..\\rap\r\nport.pdf")
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .with(hash_including(filename: "..\\rap\r\nport.pdf")).and_return("octets".b)

    expect(fetch(attachment: raw)).to be_success
  end

  # Anomalie de données amont : le téléchargement aboutit, donc le journal seul, sans signalement.
  # La ligne d'historique ne s'appariera alors à aucune pièce, conséquence connue.
  it "traces a nameless piece under the shared fallback, logged as a warning" do
    nameless = build(:portail_attachment, filename: "")
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .with(hash_including(filename: "piece")).and_return("octets".b)

    events = capture_semantic_logger_events { fetch(attachment: nameless) }

    expect(events).to include(be_a_semantic_logger_event(
      level: :warn, message: "Pièce sans nom tracée sous un nom de repli",
      payload_includes: {
        delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", id: "a1111111-1111-1111-1111-111111111111"
      }
    ))
  end

  # La trace amont atteste que le PORTAIL a retiré le fichier ; cette ligne-ci, que cet agent l'a
  # demandé. L'identifiant, pas le nom : le portail tourne sans donnée personnelle dans sa
  # supervision.
  it "logs a successful retrieval with the agent, the delivery and the piece" do
    expect(Portail::HubAPI::Attachments).to receive(:download).and_return("octets".b)

    events = capture_semantic_logger_events { fetch }

    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: "Pièce récupérée",
      payload_includes: {
        delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", id: "a1111111-1111-1111-1111-111111111111",
        agent_id: agent.id
      }
    ))
  end

  # État durable du dossier, pas incident : avertissement au journal, jamais de signalement, et une
  # issue à part — l'agent ne voit pas la même page selon la cause.
  it "fails as event limit reached, logged as a warning, when the upstream history is saturated" do
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .and_raise(Portail::HubAPI::EventLimitReached)

    result = nil
    events = capture_semantic_logger_events { result = fetch }

    expect(result).to be_failure
    expect(result.error).to eq(:event_limit_reached)
    expect(events).to include(be_a_semantic_logger_event(
      level: :warn, message: "Historique du télédossier saturé",
      payload_includes: {
        delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", id: "a1111111-1111-1111-1111-111111111111"
      }
    ))
  end

  # L'inventaire disait reçue, l'amont ne la sert plus : l'inventaire a vieilli.
  it "fails as not found, logged under its own reason, when the upstream no longer serves the piece" do
    expect(Portail::HubAPI::Attachments).to receive(:download).and_raise(Portail::HubAPI::NotFound)

    result = nil
    events = capture_semantic_logger_events { result = fetch }

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: "Pièce non livrable",
      payload_includes: {
        delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", id: "a1111111-1111-1111-1111-111111111111",
        reason: :gone_upstream
      }
    ))
  end

  # Le contenu non servi est déjà journalisé par la frontière, la panne déjà signalée : ici,
  # seulement le journal et l'échec, sous un même mode dégradé.
  %w[ContentUnavailable Unavailable].each do |error|
    it "fails as unavailable, logged, when the upstream raises #{error}" do
      expect(Portail::HubAPI::Attachments).to receive(:download)
        .and_raise(Portail::HubAPI.const_get(error))

      result = nil
      events = capture_semantic_logger_events { result = fetch }

      expect(result).to be_failure
      expect(result.error).to eq(:unavailable)
      expect(events).to include(be_a_semantic_logger_event(
        level: :error, message: "Pièce indisponible",
        payload_includes: {
          delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", id: "a1111111-1111-1111-1111-111111111111",
          error: "Portail::HubAPI::#{error}"
        }
      ))
    end
  end
end
