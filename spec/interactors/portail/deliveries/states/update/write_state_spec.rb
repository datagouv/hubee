# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::States::Update::WriteState do
  subject(:result) do
    described_class.call(membership: membership, delivery: delivery, state: "done",
      author: "Camille MARTIN")
  end

  let(:membership) do
    create(:membership,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
  end
  let(:delivery) { build(:portail_delivery, state: "in_progress") }

  it "keeps the event the upstream wrote" do
    event = build(:portail_event)
    expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_return(event)

    expect(result.event).to eq(event)
  end

  # Le couple doit venir du rattachement : pris ailleurs, il ouvrirait une autre structure. Et le
  # texte part vers l'émetteur du dossier, qui le lit.
  it "writes within the organisation of the membership, under the agent name" do
    expect(Portail::HubAPI::Deliveries).to receive(:change_state).with(
      id: delivery.id, state: "done", author: "Camille MARTIN",
      message: "Changement du statut à DONE", siret: "22770001000019", insee_code: "77372"
    ).and_return(build(:portail_event))

    result
  end

  # Le texte part vers l'émetteur : chaque cible offerte doit en avoir un, et le sien.
  {
    "acknowledged" => "Changement du statut à SI_RECEIVED",
    "in_progress" => "Changement du statut à IN_PROGRESS",
    "awaiting_attachments" => "Changement du statut à ADD_AWAITING",
    "refused" => "Changement du statut à REFUSED",
    "done" => "Changement du statut à DONE"
  }.each do |state, message|
    it "names the #{state} move the way the existing history does" do
      # hash_including : le hash complet est asserté une fois plus haut, seul le couple varie ici.
      expect(Portail::HubAPI::Deliveries).to receive(:change_state)
        .with(hash_including(state: state, message: message))
        .and_return(build(:portail_event))

      described_class.call(membership: membership, delivery: delivery, state: state,
        author: "Camille MARTIN")
    end
  end

  # Un auteur vide passerait la garde de la gem en « paramètre refusé », qu'on afficherait en
  # panne passagère : l'agent réessaierait indéfiniment sans que rien n'atteigne la supervision.
  it "refuses before writing when the agent has no name to sign with" do
    expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

    result = described_class.call(membership: membership, delivery: delivery, state: "done",
      author: "")

    expect(result.error).to eq(:unknown_author)
  end

  # Plutôt échouer que publier « translation missing » dans l'historique que lit l'émetteur.
  # Inatteignable depuis l'organizer aujourd'hui, la table refuse « clos » avant : garde du jour
  # où un état entrerait dans le cycle sans son texte.
  it "refuses before writing when the move carries no text" do
    expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

    result = described_class.call(membership: membership, delivery: delivery, state: "closed",
      author: "Camille MARTIN")

    expect(result.error).to eq(:unavailable)
  end

  {
    Portail::HubAPI::NotFound => :not_found,
    Portail::HubAPI::AwaitingAttachmentsNotAllowed => :awaiting_attachments_not_allowed,
    Portail::HubAPI::EventLimitReached => :event_limit_reached,
    Portail::HubAPI::Unavailable => :unavailable
  }.each do |raised, error|
    it "fails with #{error} when the upstream raises #{raised.name.demodulize}" do
      expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_raise(raised)

      expect(result.error).to eq(error)
    end
  end

  # L'état est déjà filtré quand on écrit : un refus de paramètre est un défaut du portail, pas
  # un geste de l'agent. Il se signale, il ne se déguise ni en panne ni en transition impossible.
  it "reports a parameter refusal as a portal defect and fails as rejected" do
    expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_raise(Portail::HubAPI::InvalidRequest)
    expect(Rails.error).to receive(:report).with(instance_of(Portail::HubAPI::InvalidRequest), handled: true)

    expect(result.error).to eq(:rejected)
  end
end
