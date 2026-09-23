# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::States::Update::EnsureReplyAccepted do
  let(:delivery) { build(:portail_delivery, state: "in_progress") }

  def serve(**rules)
    expect(Portail::HubAPI::DataStreams).to receive(:fetch).with("CERTDC")
      .and_return(build(:portail_data_stream, v1: build(:portail_data_stream_v1_rules, **rules)))
  end

  def check(reply = portail_reply)
    described_class.call(delivery: delivery, reply: reply)
  end

  it "lets a state change without a reply through, without reading the data stream" do
    expect(Portail::HubAPI::DataStreams).not_to receive(:fetch)

    expect(check(nil)).to be_a_success
  end

  it "accepts a piece the data stream takes from the current state" do
    serve

    expect(check).to be_a_success
  end

  it "refuses a piece the data stream no longer accepts from the current state" do
    serve(attachment_states: %w[done])

    expect(check.error).to eq(:attachment_not_accepted)
  end

  it "refuses a format the data stream does not list" do
    serve(attachment_content_types: ["image/png"])

    expect(check.error).to eq(:attachment_format)
  end

  it "refuses a piece heavier than the data stream allows" do
    serve(attachment_max_byte_size: 10)

    expect(check.error).to eq(:attachment_too_large)
  end

  it "refuses an empty file" do
    serve

    expect(check(portail_reply(bytes: "".b)).error).to eq(:attachment_empty)
  end

  it "refuses a name longer than the upstream stores" do
    serve

    expect(check(portail_reply(filename: "#{"a" * 252}.pdf")).error).to eq(:attachment_filename)
  end

  it "refuses a reply whose name is empty" do
    serve

    expect(check(portail_reply(filename: "/")).error).to eq(:attachment_filename)
  end

  it "refuses to go on when the data stream cannot be read" do
    expect(Portail::HubAPI::DataStreams).to receive(:fetch).and_return(nil)

    expect(check.error).to eq(:unavailable)
  end
end
