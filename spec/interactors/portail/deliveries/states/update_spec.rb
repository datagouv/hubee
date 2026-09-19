# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::States::Update do
  let(:membership) { create(:membership) }
  let(:delivery) { build(:portail_delivery, state: "in_progress") }

  # La validation lit le flux du télédossier en amont : le client factice le sert, permissif.
  before { use_hub_api_fake_client.add_data_stream(build_v2_data_stream(code: "CERTDC")) }

  def change_state(state: "done")
    described_class.call(membership: membership, delivery: delivery, state: state, author: "Camille MARTIN")
  end

  it "writes the state change when everything lines up" do
    expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_return(build(:portail_event))

    expect(change_state).to be_a_success
  end

  # Le refus local passe avant l'écriture : rien ne part en amont pour rien.
  it "does not write when the transition is not offered" do
    expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

    expect(change_state(state: "transmitted").error).to eq(:invalid_request)
  end
end
