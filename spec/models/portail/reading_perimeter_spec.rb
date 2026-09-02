# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::ReadingPerimeter do
  # Le rôle ne tranche que la liste vide : tout pour l'administrateur local, rien pour le membre.
  describe ".for" do
    context "for a member without habilitation" do
      let(:membership) { create(:membership) }

      it "gives no access at all" do
        expect(described_class.for(membership)).to be_none
      end

      # Deux agents de la même organisation n'ont pas le même périmètre.
      it "ignores the habilitations of other memberships" do
        other = create(:membership, organization_link: membership.organization_link)
        create(:process_access, membership: other, process_code: "AEC")

        expect(described_class.for(membership)).to be_none
      end
    end

    context "for a member habilitated on CERTDC and AEC" do
      let(:membership) { create(:membership) }

      before do
        create(:process_access, membership: membership, process_code: "CERTDC")
        create(:process_access, membership: membership, process_code: "AEC")
      end

      it "limits the reading to those data streams" do
        expect(described_class.for(membership).filter).to contain_exactly("CERTDC", "AEC")
      end
    end

    context "for a local administrator without habilitation" do
      let(:membership) { create(:membership, :local_administrator) }

      it "leaves the reading unrestricted" do
        expect(described_class.for(membership)).to be_unrestricted
      end
    end

    # Le cas qui distingue cette règle de « l'administrateur voit tout ».
    context "for a local administrator habilitated on CERTDC" do
      let(:membership) { create(:membership, :local_administrator) }

      before { create(:process_access, membership: membership, process_code: "CERTDC") }

      it "limits the reading to that data stream" do
        perimeter = described_class.for(membership)

        expect(perimeter).not_to be_unrestricted
        expect(perimeter.filter).to contain_exactly("CERTDC")
      end
    end
  end

  describe "#covers?" do
    it "covers every data stream when unrestricted" do
      expect(described_class.unrestricted.covers?("AEC")).to be(true)
    end

    it "covers only the listed data streams when limited" do
      perimeter = described_class.limited_to(["CERTDC"])

      expect(perimeter.covers?("CERTDC")).to be(true)
      expect(perimeter.covers?("AEC")).to be(false)
    end

    it "covers nothing when there is no access" do
      expect(described_class.none.covers?("CERTDC")).to be(false)
    end
  end

  it "never confuses no restriction with no access" do
    expect(described_class.unrestricted).not_to be_none
    expect(described_class.none).not_to be_unrestricted
  end

  describe "#filter" do
    it "hands the upstream an empty filter when nothing restricts the reading" do
      expect(described_class.unrestricted.filter).to eq([])
    end

    it "hands the upstream the listed codes when limited" do
      expect(described_class.limited_to(["CERTDC", "AEC"]).filter).to eq(["CERTDC", "AEC"])
    end

    # Un filtre vide envoyé à l'amont vaudrait toute l'organisation : l'oubli du court-circuit
    # doit exploser, pas ouvrir la lecture.
    it "refuses to hand any filter when there is no access" do
      expect { described_class.none.filter }.to raise_error(described_class::NoAccess)
    end
  end
end
