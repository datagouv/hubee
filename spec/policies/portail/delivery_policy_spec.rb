# frozen_string_literal: true

require "rails_helper"

# La règle rôle × habilitation est éprouvée dans le spec de Portail::Access::ProcessPerimeter. Ici, on
# constate que la policy l'applique à ce que l'amont a servi, liste et détail, et qu'elle vérifie
# aussi l'organisation : l'amont est un tiers, son filtre n'est pas tenu pour acquis.
RSpec.describe Portail::DeliveryPolicy do
  def scope(*deliveries) = described_class::Scope.new(membership, deliveries).resolve

  def show?(delivery) = described_class.new(membership, delivery).show?

  context "for a member without habilitation" do
    let(:membership) { create(:membership) }

    describe "Scope#resolve" do
      it "keeps nothing" do
        delivery = build(:portail_delivery, membership: membership)

        expect(scope(delivery)).to be_empty
      end
    end

    describe "#show?" do
      it "refuses any delivery" do
        delivery = build(:portail_delivery, membership: membership)

        expect(show?(delivery)).to be(false)
      end
    end
  end

  context "for a member habilitated on CERTDC" do
    let(:membership) { create(:membership) }

    before { create(:process_access, membership: membership, process_code: "CERTDC") }

    describe "Scope#resolve" do
      it "keeps CERTDC for the organisation, drops another data stream or another organisation" do
        kept = build(:portail_delivery, membership: membership)
        other_stream = build(:portail_delivery, data_stream_code: "AEC", membership: membership)
        other_organisation = build(:portail_delivery, :of_another_organisation)

        expect(scope(kept, other_stream, other_organisation)).to eq([kept])
      end
    end

    describe "#show?" do
      it "accepts a delivery on CERTDC for the organisation" do
        delivery = build(:portail_delivery, membership: membership)

        expect(show?(delivery)).to be(true)
      end

      # Le trou que cette policy ferme : la liste ne montre pas cette démarche, mais son
      # identifiant suffirait à l'ouvrir.
      it "refuses a delivery on another data stream" do
        delivery = build(:portail_delivery, data_stream_code: "AEC", membership: membership)

        expect(show?(delivery)).to be(false)
      end

      # La requête amont porte déjà l'organisation ; ceci vérifie que l'amont l'a respectée.
      it "refuses a delivery of another organisation" do
        delivery = build(:portail_delivery, :of_another_organisation)

        expect(show?(delivery)).to be(false)
      end
    end
  end

  context "for a local administrator without habilitation" do
    let(:membership) { create(:membership, :local_administrator) }

    describe "Scope#resolve" do
      it "keeps every data stream of the organisation, drops another organisation" do
        kept = [
          build(:portail_delivery, membership: membership),
          build(:portail_delivery, data_stream_code: "AEC", membership: membership)
        ]
        other_organisation = build(:portail_delivery, :of_another_organisation)

        expect(scope(*kept, other_organisation)).to eq(kept)
      end
    end

    describe "#show?" do
      it "accepts a delivery on any data stream of the organisation" do
        delivery = build(:portail_delivery, data_stream_code: "AEC", membership: membership)

        expect(show?(delivery)).to be(true)
      end

      it "refuses a delivery of another organisation" do
        delivery = build(:portail_delivery, :of_another_organisation)

        expect(show?(delivery)).to be(false)
      end
    end
  end

  # Le cas qui distingue cette règle de « l'administrateur voit tout ».
  context "for a local administrator habilitated on CERTDC" do
    let(:membership) { create(:membership, :local_administrator) }

    before { create(:process_access, membership: membership, process_code: "CERTDC") }

    describe "Scope#resolve" do
      it "keeps CERTDC only" do
        kept = build(:portail_delivery, membership: membership)
        other_stream = build(:portail_delivery, data_stream_code: "AEC", membership: membership)

        expect(scope(kept, other_stream)).to eq([kept])
      end
    end

    describe "#show?" do
      it "accepts a delivery on CERTDC" do
        delivery = build(:portail_delivery, membership: membership)

        expect(show?(delivery)).to be(true)
      end

      it "refuses a delivery on another data stream" do
        delivery = build(:portail_delivery, data_stream_code: "AEC", membership: membership)

        expect(show?(delivery)).to be(false)
      end
    end
  end
end
