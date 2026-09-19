# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::States::Update do
  let(:membership) { create(:membership) }
  let(:delivery) { build(:portail_delivery, state: "in_progress") }

  def change_state(state: "done", seen_state: "in_progress")
    described_class.call(membership: membership, delivery: delivery, state: state,
      seen_state: seen_state, author: "Camille MARTIN")
  end

  it "writes the state change when everything lines up" do
    expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_return(build(:portail_event))

    expect(change_state).to be_a_success
  end

  # Les deux refus locaux passent avant l'écriture : rien ne part en amont pour rien.
  it "does not write when the transition is not offered" do
    expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

    expect(change_state(state: "transmitted").error).to eq(:invalid_request)
  end

  it "does not write when the delivery moved since the agent saw it" do
    expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

    expect(change_state(seen_state: "transmitted").error).to eq(:stale_state)
  end

  # Un agent dont la page a vieilli doit s'entendre dire de la recharger. Si la table tranchait
  # la première, il lirait « transition impossible » et ne saurait pas que le dossier a bougé.
  it "tells a stale page apart from an impossible move" do
    expect(change_state(state: "transmitted", seen_state: "transmitted").error).to eq(:stale_state)
  end
end
