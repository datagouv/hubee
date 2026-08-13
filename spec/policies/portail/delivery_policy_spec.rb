# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::DeliveryPolicy do
  describe "Scope#resolve" do
    it "renvoie nil pour un administrateur local, qui voit tout le périmètre" do
      membership = create(:membership, :local_administrator)
      create(:process_access, membership: membership, process_code: "CERTDC")

      expect(described_class::Scope.new(membership).resolve).to be_nil
    end

    it "renvoie les codes habilités pour un membre" do
      membership = create(:membership)
      create(:process_access, membership: membership, process_code: "CERTDC")
      create(:process_access, membership: membership, process_code: "AEC")

      expect(described_class::Scope.new(membership).resolve).to contain_exactly("CERTDC", "AEC")
    end

    it "renvoie un tableau vide pour un membre sans aucune habilitation" do
      membership = create(:membership)

      expect(described_class::Scope.new(membership).resolve).to eq([])
    end

    # Le cas qui fait la valeur de cette classe : deux agents de la même organisation n'ont
    # pas le même périmètre, et une jointure trop large les confondrait.
    it "ignore les habilitations des autres rattachements" do
      link = create(:organization_link)
      membership = create(:membership, organization_link: link)
      autre = create(:membership, organization_link: link)
      create(:process_access, membership: autre, process_code: "AEC")

      expect(described_class::Scope.new(membership).resolve).to eq([])
    end
  end

  describe "#show?" do
    it "autorise un administrateur local sur n'importe quel flux de sa structure" do
      membership = create(:membership, :local_administrator)
      delivery = build_delivery(data_stream: HubApiV1::V2::DataStream.new(code: "AEC"))

      expect(described_class.new(membership, delivery).show?).to be(true)
    end

    it "autorise un membre sur un flux qu'il est habilité à lire" do
      membership = create(:membership)
      create(:process_access, membership: membership, process_code: "CERTDC")
      delivery = build_delivery(data_stream: HubApiV1::V2::DataStream.new(code: "CERTDC"))

      expect(described_class.new(membership, delivery).show?).to be(true)
    end

    # Le trou que cette policy ferme : la liste ne montre pas cette démarche, mais son
    # identifiant suffirait à l'ouvrir si personne ne vérifiait ici.
    it "refuse un membre sur un flux hors de ses habilitations" do
      membership = create(:membership)
      create(:process_access, membership: membership, process_code: "CERTDC")
      delivery = build_delivery(data_stream: HubApiV1::V2::DataStream.new(code: "AEC"))

      expect(described_class.new(membership, delivery).show?).to be(false)
    end

    it "refuse un membre sans aucune habilitation" do
      membership = create(:membership)
      delivery = build_delivery(data_stream: HubApiV1::V2::DataStream.new(code: "CERTDC"))

      expect(described_class.new(membership, delivery).show?).to be(false)
    end
  end
end
