# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::States::Shared::EnsureTransitionAllowed do
  subject(:result) { described_class.call(delivery: delivery, state: state) }

  let(:delivery) { build(:portail_delivery, :retrieved, state: "in_progress") }

  # Le flux du télédossier, tel que l'amont le sert : permissif sauf mention contraire.
  def upstream_serves_a_data_stream(**overrides)
    use_hub_api_fake_client.add_data_stream(build_v2_data_stream(code: "CERTDC", **overrides))
  end

  context "when the table offers the target state" do
    let(:state) { "done" }

    it "lets the change through" do
      upstream_serves_a_data_stream

      expect(result).to be_a_success
    end
  end

  context "when the table does not offer the target state" do
    let(:state) { "transmitted" }

    it "refuses the change" do
      upstream_serves_a_data_stream

      expect(result.error).to eq(:invalid_request)
    end
  end

  context "when the target state is outside the perimeter the portal serves" do
    let(:state) { "integration_error" }

    it "refuses the change" do
      upstream_serves_a_data_stream

      expect(result.error).to eq(:invalid_request)
    end
  end

  context "when the target state is closed" do
    let(:state) { "closed" }

    it "refuses the change, because closing belongs to the sender" do
      upstream_serves_a_data_stream

      expect(result.error).to eq(:invalid_request)
    end
  end

  context "when awaiting attachments is asked" do
    let(:state) { "awaiting_attachments" }

    it "lets the change through when the data stream allows it" do
      upstream_serves_a_data_stream

      expect(result).to be_a_success
    end

    it "refuses the change, as the data stream withholding it, when the data stream forbids it" do
      upstream_serves_a_data_stream(allowed_states: HubApiV1::V2::Mapping::ORDERED_STATES - [:awaiting_attachments])

      expect(result.error).to eq(:state_not_allowed_by_stream)
    end

    # Priver l'agent d'une action parce qu'une lecture accessoire a échoué serait pire que de lui
    # montrer le refus qui viendra. Le faux client ne connaît pas le flux : lecture en échec.
    it "lets the change through when the data stream cannot be read" do
      use_hub_api_fake_client

      expect(result).to be_a_success
    end
  end

  # L'amont ne fait varier aujourd'hui que l'attente de compléments, le faux client aussi : le flux
  # est servi tel que le portail le lit, pour ne pas en faire une règle.
  context "when a decision is asked that the data stream withholds" do
    let(:state) { "refused" }

    it "refuses the change as the data stream withholding it" do
      expect(Portail::HubAPI::DataStreams).to receive(:fetch).with("CERTDC")
        .and_return(build(:portail_data_stream, allowed_states: %w[transmitted acknowledged in_progress done closed]))

      expect(result.error).to eq(:state_not_allowed_by_stream)
    end
  end

  context "when the delivery was never retrieved" do
    context "when a decision is asked" do
      it "refuses the change with the generic refusal" do
        upstream_serves_a_data_stream

        result = described_class.call(delivery: build(:portail_delivery, state: "in_progress"), state: "done")

        expect(result.error).to eq(:invalid_request)
      end

      it "refuses the change with the generic refusal when the data stream cannot be read" do
        use_hub_api_fake_client

        result = described_class.call(delivery: build(:portail_delivery, state: "in_progress"), state: "done")

        expect(result.error).to eq(:invalid_request)
      end
    end

    context "when awaiting attachments is asked" do
      it "lets the change through" do
        upstream_serves_a_data_stream

        result = described_class.call(delivery: build(:portail_delivery, state: "in_progress"), state: "awaiting_attachments")

        expect(result).to be_a_success
      end

      it "refuses the change, as the data stream withholding it, when the data stream forbids it" do
        upstream_serves_a_data_stream(allowed_states: HubApiV1::V2::Mapping::ORDERED_STATES - [:awaiting_attachments])

        result = described_class.call(delivery: build(:portail_delivery, state: "in_progress"), state: "awaiting_attachments")

        expect(result.error).to eq(:state_not_allowed_by_stream)
      end
    end

    it "refuses a decision the table no longer offers as impossible" do
      upstream_serves_a_data_stream

      result = described_class.call(delivery: build(:portail_delivery, state: "refused"), state: "in_progress")

      expect(result.error).to eq(:invalid_request)
    end
  end

  # Une cible que la table refuse reste une transition impossible, même si le flux la retient
  # aussi : c'est la table qui parle la première à l'agent.
  it "refuses a move the table does not offer as impossible, whatever the data stream" do
    upstream_serves_a_data_stream(allowed_states: HubApiV1::V2::Mapping::ORDERED_STATES - [:awaiting_attachments])

    result = described_class.call(delivery: build(:portail_delivery, :retrieved, state: "done"), state: "awaiting_attachments")

    expect(result.error).to eq(:invalid_request)
  end
end
