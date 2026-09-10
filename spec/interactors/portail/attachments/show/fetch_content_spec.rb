# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Attachments::Show::FetchContent do
  let(:membership) do
    create(:membership,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
  end

  # Le périmètre doit venir du rattachement, ses trois dimensions ensemble : le couple pris
  # ailleurs ouvrirait une autre structure, et des habilitations perdues en route vaudraient
  # « aucun filtre » en aval, donc toute l'organisation. L'auteur voyage dans le même appel : la
  # gem inscrit la trace dans le même geste, et refuse un auteur blanc.
  it "fetches the content within the whole perimeter of the membership" do
    create(:process_access, membership: membership, process_code: "CERTDC")
    agent = create(:agent, first_name: "George", last_name: "DUBOIS")
    content = build(:portail_attachment_content)
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .with(delivery_id: "a-delivery", id: "an-id", author: "George DUBOIS",
        siret: "22770001000019", insee_code: "77372", data_stream_codes: ["CERTDC"])
      .and_return(content)

    result = described_class.call(membership: membership, agent: agent,
      delivery_id: "a-delivery", id: "an-id")

    expect(result).to be_success
    expect(result.content).to eq(content)
  end

  # L'administrateur local sans habilitation lit toute son organisation : la liste vide est une
  # décision, et c'est bien pourquoi l'exemple ci-dessus vérifie que les codes voyagent.
  it "sends an unrestricted perimeter for a local administrator without habilitation" do
    membership.update!(role: "local_administrator")
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .with(hash_including(data_stream_codes: []))
      .and_return(build(:portail_attachment_content))

    result = described_class.call(membership: membership, agent: create(:agent), delivery_id: "a-delivery", id: "an-id")

    expect(result).to be_success
  end

  # Un membre sans habilitation est refusé AVANT tout appel : son périmètre vide, transmis en
  # aval, vaudrait « aucun filtre ».
  it "refuses a member without any habilitation, without reaching the upstream" do
    expect(Portail::HubAPI::Attachments).not_to receive(:download)

    result = described_class.call(membership: membership, agent: create(:agent), delivery_id: "a-delivery", id: "an-id")

    expect(result).to be_failure
    expect(result.error).to eq(:out_of_perimeter)
  end

  # Le nom d'usage est facultatif côté fournisseur d'identité, l'adresse ne l'est pas : une trace
  # anonyme ne trace rien, et la gem refuse un auteur blanc.
  it "falls back to the address when the agent carries no name" do
    create(:process_access, membership: membership, process_code: "CERTDC")
    agent = create(:agent, first_name: nil, last_name: nil, email: "agent@exemple.fr")
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .with(hash_including(author: "agent@exemple.fr"))
      .and_return(build(:portail_attachment_content))

    result = described_class.call(membership: membership, agent: agent,
      delivery_id: "a-delivery", id: "an-id")

    expect(result).to be_success
  end

  it "keeps the half of the name the provider did serve" do
    create(:process_access, membership: membership, process_code: "CERTDC")
    agent = create(:agent, first_name: nil, last_name: "DUBOIS")
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .with(hash_including(author: "DUBOIS"))
      .and_return(build(:portail_attachment_content))

    described_class.call(membership: membership, agent: agent,
      delivery_id: "a-delivery", id: "an-id")
  end

  # La gem refuse AVANT de rapatrier l'octet : rien n'a été transféré pour un fichier qu'on ne
  # pourra pas tracer. L'agent ne peut rien y faire et le service n'est pas en panne — d'où
  # l'avertissement, pour que la saturation se voie avant qu'il n'appelle.
  it "fails as history full, warned, when the delivery can take no more events" do
    create(:process_access, membership: membership, process_code: "CERTDC")
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .and_raise(Portail::HubAPI::HistoryFull)

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, agent: create(:agent),
        delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", id: "a1111111-1111-1111-1111-111111111111")
    end

    expect(result).to be_failure
    expect(result.error).to eq(:history_full)
    expect(events).to include(be_a_semantic_logger_event(
      level: :warn, message: "Historique de démarche saturé, téléchargement refusé",
      payload_includes: {delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2",
                         id: "a1111111-1111-1111-1111-111111111111"}
    ))
  end

  # Le bornage amont a refusé : aucun motif n'est journalisé ici, la gem confond ses causes à
  # dessein et c'est le contrôleur qui porte le signalement au CSIRT.
  it "fails as out of perimeter when the upstream perimeter refused the read" do
    create(:process_access, membership: membership, process_code: "CERTDC")
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .and_raise(Portail::HubAPI::NotFound)

    result = described_class.call(membership: membership, agent: create(:agent), delivery_id: "a-delivery", id: "an-id")

    expect(result).to be_failure
    expect(result.error).to eq(:out_of_perimeter)
  end

  # Les identifiants en champs, pas dans le message : ils se filtrent au journal, et `reason`
  # sépare la pièce que l'amont ne sert pas du bruit des identifiants malformés.
  it "fails as not found, logged under searchable identifiers, when the piece is not served" do
    create(:process_access, membership: membership, process_code: "CERTDC")
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .and_raise(Portail::HubAPI::AttachmentNotFound)

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, agent: create(:agent),
        delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", id: "a1111111-1111-1111-1111-111111111111")
    end

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: "Pièce introuvable en amont",
      payload_includes: {delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2",
                         id: "a1111111-1111-1111-1111-111111111111", reason: :unknown}
    ))
  end

  it "treats a refused argument as not found, logged under its own reason" do
    create(:process_access, membership: membership, process_code: "CERTDC")
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .and_raise(Portail::HubAPI::InvalidRequest)

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, agent: create(:agent), delivery_id: " ", id: " ")
    end

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: "Pièce introuvable en amont", payload_includes: {reason: :invalid_id}
    ))
  end

  # Son propre motif d'échec, distinct de la panne : la cause la plus courante est une pièce dont
  # le binaire a été purgé alors que son état annonce toujours « reçue ». Promettre « réessayez »
  # serait faux. En avertissement et non en erreur : c'est un cas courant, pas un incident.
  it "fails as content unavailable, warned and not reported, when the bytes cannot be served" do
    create(:process_access, membership: membership, process_code: "CERTDC")
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .and_raise(Portail::HubAPI::AttachmentUnavailable)

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, agent: create(:agent),
        delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", id: "a1111111-1111-1111-1111-111111111111")
    end

    expect(result).to be_failure
    expect(result.error).to eq(:content_unavailable)
    expect(events).to include(be_a_semantic_logger_event(
      level: :warn, message: "Contenu de pièce indisponible en amont",
      payload_includes: {delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2",
                         id: "a1111111-1111-1111-1111-111111111111"}
    ))
  end

  # La panne est signalée par la couche de traduction : ici, seulement le journal et l'échec.
  it "fails as unavailable, logged, when the upstream is failing" do
    create(:process_access, membership: membership, process_code: "CERTDC")
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .and_raise(Portail::HubAPI::Unavailable)

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, agent: create(:agent), delivery_id: "a-delivery", id: "an-id")
    end

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
    expect(events).to include(be_a_semantic_logger_event(
      level: :error, message_includes: "Pièce indisponible"
    ))
  end
end
