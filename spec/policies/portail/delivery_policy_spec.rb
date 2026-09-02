# frozen_string_literal: true

require "rails_helper"

# La règle rôle × habilitation est éprouvée dans le spec de Portail::ReadingPerimeter. Ici, on
# constate que la policy l'applique sur ses deux faces, la liste et le détail.
RSpec.describe Portail::DeliveryPolicy do
  describe "Scope#resolve" do
    def scope = described_class::Scope.new(membership).resolve

    context "for a member without habilitation" do
      let(:membership) { create(:membership) }

      it "closes the list" do
        expect(scope).to be_none
      end
    end

    context "for a member habilitated on CERTDC" do
      let(:membership) { create(:membership) }

      before { create(:process_access, membership: membership, process_code: "CERTDC") }

      it "bounds the list to CERTDC" do
        expect(scope.filter).to contain_exactly("CERTDC")
      end
    end

    context "for a local administrator without habilitation" do
      let(:membership) { create(:membership, :local_administrator) }

      it "leaves the list unrestricted" do
        expect(scope).to be_unrestricted
      end
    end

    context "for a local administrator habilitated on CERTDC" do
      let(:membership) { create(:membership, :local_administrator) }

      before { create(:process_access, membership: membership, process_code: "CERTDC") }

      it "bounds the list to CERTDC" do
        expect(scope).not_to be_unrestricted
        expect(scope.filter).to contain_exactly("CERTDC")
      end
    end
  end

  describe "#show?" do
    def policy_on(data_stream_code)
      described_class.new(membership, build(:portail_delivery, data_stream_code: data_stream_code))
    end

    context "for a member without habilitation" do
      let(:membership) { create(:membership) }

      it "refuses any delivery" do
        expect(policy_on("CERTDC").show?).to be(false)
      end
    end

    context "for a member habilitated on CERTDC" do
      let(:membership) { create(:membership) }

      before { create(:process_access, membership: membership, process_code: "CERTDC") }

      it "accepts a delivery on CERTDC" do
        expect(policy_on("CERTDC").show?).to be(true)
      end

      # Le trou que cette policy ferme : la liste ne montre pas cette démarche, mais son
      # identifiant suffirait à l'ouvrir.
      it "refuses a delivery on another data stream" do
        expect(policy_on("AEC").show?).to be(false)
      end
    end

    context "for a local administrator without habilitation" do
      let(:membership) { create(:membership, :local_administrator) }

      it "accepts a delivery on any data stream" do
        expect(policy_on("AEC").show?).to be(true)
      end
    end

    context "for a local administrator habilitated on CERTDC" do
      let(:membership) { create(:membership, :local_administrator) }

      before { create(:process_access, membership: membership, process_code: "CERTDC") }

      it "accepts a delivery on CERTDC" do
        expect(policy_on("CERTDC").show?).to be(true)
      end

      it "refuses a delivery on another data stream" do
        expect(policy_on("AEC").show?).to be(false)
      end
    end
  end
end
