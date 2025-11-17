# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataPackages::Transmit::ResolveRecipients do
  describe ".call" do
    let(:data_stream) { create(:data_stream) }
    let(:data_package) { create(:data_package, :draft, data_stream: data_stream) }
    subject(:result) { described_class.call(data_package: data_package) }

    context "with criteria matching subscriptions" do
      let(:org) { create(:organization, siret: "13002526500013") }
      let!(:subscription) { create(:subscription, data_stream: data_stream, organization: org, can_read: true) }

      before { data_package.update!(delivery_criteria: {"siret" => "13002526500013"}) }

      it { is_expected.to be_success }

      it "provides target subscriptions in context" do
        expect(result.target_subscriptions).to include(subscription)
      end
    end

    context "with no matching subscriptions" do
      before { data_package.update!(delivery_criteria: {"siret" => "99999999999999"}) }

      it { is_expected.to be_failure }

      it "returns no_recipients error" do
        expect(result.error).to eq(:no_recipients)
      end
    end

    context "with nil criteria" do
      before { data_package.update!(delivery_criteria: nil) }

      it { is_expected.to be_failure }

      it "returns no_recipients error" do
        expect(result.error).to eq(:no_recipients)
      end
    end
  end
end
