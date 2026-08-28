# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::DeliveryPolicy do
  describe "Scope#resolve" do
    it "returns nil for a local administrator, who sees the whole perimeter" do
      membership = create(:membership, :local_administrator)
      create(:process_access, membership: membership, process_code: "CERTDC")

      expect(described_class::Scope.new(membership).resolve).to be_nil
    end

    it "returns the habilitated codes for a member" do
      membership = create(:membership)
      create(:process_access, membership: membership, process_code: "CERTDC")
      create(:process_access, membership: membership, process_code: "AEC")

      expect(described_class::Scope.new(membership).resolve).to contain_exactly("CERTDC", "AEC")
    end

    it "returns an empty array for a member without any habilitation" do
      membership = create(:membership)

      expect(described_class::Scope.new(membership).resolve).to eq([])
    end

    # Le cas qui fait la valeur de cette classe : deux agents de la même organisation n'ont
    # pas le même périmètre, et une jointure trop large les confondrait.
    it "ignores the habilitations of other memberships" do
      link = create(:organization_link)
      membership = create(:membership, organization_link: link)
      autre = create(:membership, organization_link: link)
      create(:process_access, membership: autre, process_code: "AEC")

      expect(described_class::Scope.new(membership).resolve).to eq([])
    end
  end

  describe "#show?" do
    it "allows a local administrator on any data stream of their organisation" do
      membership = create(:membership, :local_administrator)
      delivery = build_v2_delivery(data_stream: HubApiV1::V2::DataStream.new(code: "AEC"))

      expect(described_class.new(membership, delivery).show?).to be(true)
    end

    it "allows a member on a data stream they are habilitated to read" do
      membership = create(:membership)
      create(:process_access, membership: membership, process_code: "CERTDC")
      delivery = build_v2_delivery(data_stream: HubApiV1::V2::DataStream.new(code: "CERTDC"))

      expect(described_class.new(membership, delivery).show?).to be(true)
    end

    # Le trou que cette policy ferme : la liste ne montre pas cette démarche, mais son
    # identifiant suffirait à l'ouvrir si personne ne vérifiait ici.
    it "refuses a member on a data stream outside their habilitations" do
      membership = create(:membership)
      create(:process_access, membership: membership, process_code: "CERTDC")
      delivery = build_v2_delivery(data_stream: HubApiV1::V2::DataStream.new(code: "AEC"))

      expect(described_class.new(membership, delivery).show?).to be(false)
    end

    it "refuses a member without any habilitation" do
      membership = create(:membership)
      delivery = build_v2_delivery(data_stream: HubApiV1::V2::DataStream.new(code: "CERTDC"))

      expect(described_class.new(membership, delivery).show?).to be(false)
    end
  end
end
