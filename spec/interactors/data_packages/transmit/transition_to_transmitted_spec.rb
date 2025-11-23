# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataPackages::Transmit::TransitionToTransmitted do
  describe ".call" do
    let(:data_package) { create(:data_package, :draft) }
    subject(:result) { described_class.call(data_package: data_package) }

    it { is_expected.to be_success }

    it "transitions to transmitted state" do
      result
      expect(data_package.reload.state).to eq("transmitted")
    end

    it "sets sent_at timestamp" do
      result
      expect(data_package.reload.sent_at).to be_within(1.second).of(Time.current)
    end
  end
end
