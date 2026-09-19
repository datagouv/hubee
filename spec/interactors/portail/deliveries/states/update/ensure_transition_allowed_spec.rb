# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::States::Update::EnsureTransitionAllowed do
  subject(:result) { described_class.call(delivery: delivery, state: state) }

  let(:delivery) { build(:portail_delivery, state: "in_progress") }

  context "when the table offers the target state" do
    let(:state) { "done" }

    it "lets the change through" do
      expect(result).to be_a_success
    end
  end

  context "when the table does not offer the target state" do
    let(:state) { "transmitted" }

    it "refuses the change" do
      expect(result.error).to eq(:invalid_request)
    end
  end

  context "when the target state is outside the perimeter the portal serves" do
    let(:state) { "integration_error" }

    it "refuses the change" do
      expect(result.error).to eq(:invalid_request)
    end
  end

  context "when the target state is closed" do
    let(:state) { "closed" }

    it "refuses the change, because closing belongs to the sender" do
      expect(result.error).to eq(:invalid_request)
    end
  end

  context "when awaiting documents is asked" do
    let(:state) { "awaiting_documents" }

    it "lets the change through when the data stream allows it" do
      expect(Portail::DataStream::ProfileCache).to receive(:fetch).with("CERTDC")
        .and_return(build(:portail_data_stream_profile))

      expect(result).to be_a_success
    end

    it "refuses the change when the data stream forbids it" do
      expect(Portail::DataStream::ProfileCache).to receive(:fetch).with("CERTDC")
        .and_return(build(:portail_data_stream_profile, :without_awaiting_documents))

      expect(result.error).to eq(:awaiting_documents_not_allowed)
    end

    it "refuses the change when the data stream was never configured for it" do
      expect(Portail::DataStream::ProfileCache).to receive(:fetch).with("CERTDC")
        .and_return(build(:portail_data_stream_profile, :unconfigured))

      expect(result.error).to eq(:awaiting_documents_not_allowed)
    end

    # Priver l'agent d'une action parce qu'une lecture accessoire a échoué serait pire que de lui
    # montrer le refus qui viendra.
    it "lets the change through when the profile cannot be read" do
      expect(Portail::DataStream::ProfileCache).to receive(:fetch).with("CERTDC").and_return(nil)

      expect(result).to be_a_success
    end
  end

  # Aucun autre état n'est conditionné par la démarche : le lire serait un appel pour rien.
  it "does not read the profile for a state no data stream conditions" do
    expect(Portail::DataStream::ProfileCache).not_to receive(:fetch)

    described_class.call(delivery: delivery, state: "done")
  end
end
