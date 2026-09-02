# frozen_string_literal: true

require "rails_helper"

# La règle rôle × habilitation est éprouvée dans le spec de Portail::ReadingPerimeter. Ici, on
# constate que la policy l'applique, sur la liste et sur le détail.
RSpec.describe Portail::DeliveryPolicy do
  describe "Scope#resolve" do
    it "resolves the reading perimeter of the membership" do
      membership = create(:membership)
      create(:process_access, membership: membership, process_code: "CERTDC")

      perimeter = described_class::Scope.new(membership).resolve

      expect(perimeter).to be_a(Portail::ReadingPerimeter)
      expect(perimeter.filter).to contain_exactly("CERTDC")
    end
  end

  describe "#show?" do
    it "allows a local administrator without habilitation on any data stream" do
      membership = create(:membership, :local_administrator)
      delivery = build(:portail_delivery, data_stream_code: "AEC")

      expect(described_class.new(membership, delivery).show?).to be(true)
    end

    it "refuses a local administrator on a data stream outside their habilitations" do
      membership = create(:membership, :local_administrator)
      create(:process_access, membership: membership, process_code: "CERTDC")
      delivery = build(:portail_delivery, data_stream_code: "AEC")

      expect(described_class.new(membership, delivery).show?).to be(false)
    end

    it "allows a member on a data stream they are habilitated to read" do
      membership = create(:membership)
      create(:process_access, membership: membership, process_code: "CERTDC")
      delivery = build(:portail_delivery, data_stream_code: "CERTDC")

      expect(described_class.new(membership, delivery).show?).to be(true)
    end

    # Le trou que cette policy ferme : la liste ne montre pas cette démarche, mais son
    # identifiant suffirait à l'ouvrir.
    it "refuses a member on a data stream outside their habilitations" do
      membership = create(:membership)
      create(:process_access, membership: membership, process_code: "CERTDC")
      delivery = build(:portail_delivery, data_stream_code: "AEC")

      expect(described_class.new(membership, delivery).show?).to be(false)
    end

    it "refuses a member without any habilitation" do
      membership = create(:membership)
      delivery = build(:portail_delivery, data_stream_code: "CERTDC")

      expect(described_class.new(membership, delivery).show?).to be(false)
    end
  end
end
