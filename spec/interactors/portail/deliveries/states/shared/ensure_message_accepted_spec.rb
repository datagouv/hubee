# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::States::Shared::EnsureMessageAccepted do
  let(:delivery) { build(:portail_delivery, state: "in_progress") }

  def serve(**rules)
    expect(Portail::HubAPI::DataStreams).to receive(:fetch).with("CERTDC")
      .and_return(build(:portail_data_stream, v1: build(:portail_data_stream_v1_rules, **rules)))
  end

  def check(message)
    described_class.call(delivery: delivery, message: message)
  end

  it "lets a state change without message through, without reading the data stream" do
    expect(Portail::HubAPI::DataStreams).not_to receive(:fetch)

    expect(check(nil)).to be_a_success
  end

  it "accepts a message the data stream takes, up to the bound" do
    serve

    expect(check("a" * Portail::Delivery::StateMessage::MAX_LENGTH)).to be_a_success
  end

  # Page affichée avant un changement de réglage, ou requête forgée.
  it "refuses a message the data stream does not take" do
    serve(allows_message_with_state_change: false)

    expect(check("Pièce illisible").error).to eq(:message_not_accepted)
  end

  it "refuses a message longer than the bound" do
    serve

    expect(check("a" * (Portail::Delivery::StateMessage::MAX_LENGTH + 1)).error).to eq(:message_too_long)
  end

  # Sans règles lisibles, rien ne part : un message ne se publie que sur un accord explicite.
  it "refuses to go on when the data stream cannot be read" do
    expect(Portail::HubAPI::DataStreams).to receive(:fetch).and_return(nil)

    expect(check("Pièce illisible").error).to eq(:unavailable)
  end
end
