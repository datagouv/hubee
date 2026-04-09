# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataPackages::Transmit::ValidateTransmission do
  describe ".call" do
    let(:data_package) { create(:data_package, :draft) }
    subject(:result) { described_class.call(data_package: data_package) }

    context "when package is draft with completed attachments" do
      before { allow(data_package).to receive(:has_completed_attachments?).and_return(true) }

      it { is_expected.to be_success }
    end

    context "when package is not draft" do
      let(:data_package) { create(:data_package, :transmitted) }

      it { is_expected.to be_failure }

      it "returns not_draft error" do
        expect(result.error).to eq(:not_draft)
      end
    end

    context "when package has no completed attachments" do
      before { allow(data_package).to receive(:has_completed_attachments?).and_return(false) }

      it { is_expected.to be_failure }

      it "returns no_completed_attachments error" do
        expect(result.error).to eq(:no_completed_attachments)
      end
    end
  end
end
