# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::States::Update do
  let(:membership) { create(:membership) }
  let(:delivery) { build(:portail_delivery, state: "in_progress") }

  # La validation lit le flux du télédossier en amont : le client factice le sert, permissif.
  before { use_hub_api_fake_client.add_data_stream(build_v2_data_stream(code: "CERTDC")) }

  def change_state(state: "done", reply: nil)
    described_class.call(membership: membership, delivery: delivery, state: state,
      author: "Camille MARTIN", reply: reply)
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

  it "publishes the reply, then moves the delivery" do
    expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).ordered.and_return(build(:portail_event))
    expect(Portail::HubAPI::Deliveries).to receive(:change_state).ordered.and_return(build(:portail_event))

    expect(change_state(reply: portail_reply)).to be_a_success
  end

  it "neither publishes nor moves when the transition is not offered" do
    expect(Portail::HubAPI::Deliveries).not_to receive(:reply_with_attachment)
    expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

    expect(change_state(state: "transmitted", reply: portail_reply).error).to eq(:invalid_request)
  end

  it "leaves the state alone when the reply is refused" do
    expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).and_raise(Portail::HubAPI::AttachmentInfected)
    expect(Portail::HubAPI::Deliveries).not_to receive(:change_state)

    expect(change_state(reply: portail_reply).error).to eq(:attachment_infected)
  end

  # Le contrôleur en tire son message : la réponse est partie, l'état non.
  it "keeps the published reply when the state change fails afterwards" do
    expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).and_return(build(:portail_event))
    expect(Portail::HubAPI::Deliveries).to receive(:change_state).and_raise(Portail::HubAPI::EventLimitReached)

    result = change_state(reply: portail_reply)

    expect(result.error).to eq(:event_limit_reached)
    expect(result.reply_sent).to be(true)
  end
end
