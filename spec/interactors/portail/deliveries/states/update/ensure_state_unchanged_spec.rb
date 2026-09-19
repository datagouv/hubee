# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::States::Update::EnsureStateUnchanged do
  subject(:result) { described_class.call(delivery: delivery, seen_state: seen_state) }

  let(:delivery) { build(:portail_delivery, state: "in_progress") }

  context "when the agent saw the state the delivery still holds" do
    let(:seen_state) { "in_progress" }

    it "lets the change through" do
      expect(result).to be_a_success
    end
  end

  context "when the delivery moved since the agent saw it" do
    let(:seen_state) { "transmitted" }

    it "refuses the change, so nothing is overwritten" do
      expect(result.error).to eq(:stale_state)
    end
  end

  # Un formulaire sans état vu ne prouve rien. Une chaîne vide n'égale jamais un état servi : le
  # refus tombe par la simple comparaison, sans traitement particulier du vide.
  context "when the form carried no state at all" do
    let(:seen_state) { "" }

    it "refuses the change" do
      expect(result.error).to eq(:stale_state)
    end
  end
end
