# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::DeliveryPolicy do
  describe "Scope#resolve" do
    # Le rôle ne tranche que le sens d'une liste VIDE : pour un administrateur local elle vaut
    # « aucune restriction », pour un membre « aucune démarche ». C'est la règle du portail V1.
    it "leaves a local administrator without any habilitation unrestricted" do
      membership = create(:membership, :local_administrator)

      expect(described_class::Scope.new(membership).resolve).to be_unrestricted
    end

    # Le cas qui distingue cette règle de « l'administrateur voit tout » : une liste renseignée
    # borne tout le monde. Sans cet exemple, un administrateur habilité sur un seul flux lirait
    # tous les autres.
    it "bounds a local administrator to the codes they are habilitated to" do
      membership = create(:membership, :local_administrator)
      create(:process_access, membership: membership, process_code: "CERTDC")

      perimeter = described_class::Scope.new(membership).resolve

      expect(perimeter).not_to be_unrestricted
      expect(perimeter.filter).to contain_exactly("CERTDC")
    end

    it "bounds a member to the codes they are habilitated to" do
      membership = create(:membership)
      create(:process_access, membership: membership, process_code: "CERTDC")
      create(:process_access, membership: membership, process_code: "AEC")

      expect(described_class::Scope.new(membership).resolve.filter).to contain_exactly("CERTDC", "AEC")
    end

    it "leaves a member without any habilitation with no access at all" do
      membership = create(:membership)

      expect(described_class::Scope.new(membership).resolve).to be_none
    end

    # Le cas qui fait la valeur de cette classe : deux agents de la même organisation n'ont
    # pas le même périmètre, et une jointure trop large les confondrait.
    it "ignores the habilitations of other memberships" do
      link = create(:organization_link)
      membership = create(:membership, organization_link: link)
      autre = create(:membership, organization_link: link)
      create(:process_access, membership: autre, process_code: "AEC")

      expect(described_class::Scope.new(membership).resolve).to be_none
    end
  end

  describe "Perimeter" do
    # « Aucun filtre » et « aucun accès » ne tiennent qu'à deux littéraux voisins, `nil` et
    # `[]`, de sens exactement inverse. Les séparer est tout l'objet du type.
    it "never confuses no restriction with no access" do
      expect(described_class::Perimeter.unrestricted).not_to be_none
      expect(described_class::Perimeter.none).not_to be_unrestricted
    end

    # Ce que l'amont attend : une liste, la liste vide valant « aucun filtre ». C'est bien
    # pour cela qu'un périmètre `none?` ne doit jamais être transmis en aval.
    it "hands the upstream an empty filter when nothing restricts the reading" do
      expect(described_class::Perimeter.unrestricted.filter).to eq([])
    end
  end

  describe "#show?" do
    it "allows a local administrator without habilitation on any data stream" do
      membership = create(:membership, :local_administrator)
      delivery = build(:portail_delivery, data_stream_code: "AEC")

      expect(described_class.new(membership, delivery).show?).to be(true)
    end

    # Même règle qu'à la liste : une habilitation nommée borne aussi l'administrateur.
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
    # identifiant suffirait à l'ouvrir si personne ne vérifiait ici.
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
