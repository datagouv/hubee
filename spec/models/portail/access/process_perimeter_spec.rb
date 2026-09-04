# frozen_string_literal: true

require "rails_helper"

# Le rôle ne tranche que la liste vide : tout pour l'administrateur local, rien pour le membre.
RSpec.describe Portail::Access::ProcessPerimeter do
  context "for a member without habilitation" do
    let(:membership) { create(:membership) }

    it "gives no access at all" do
      expect(described_class.none?(membership)).to be(true)
      expect(described_class.covers?(membership, "CERTDC")).to be(false)
    end

    # Un filtre vide envoyé à l'amont vaudrait toute l'organisation : l'oubli du court-circuit
    # doit exploser, pas ouvrir la lecture.
    it "refuses to hand any filter" do
      expect { described_class.filter(membership) }.to raise_error(described_class::NoAccess)
    end

    # Deux agents de la même organisation n'ont pas le même périmètre.
    it "ignores the habilitations of other memberships" do
      other = create(:membership, organization_link: membership.organization_link)
      create(:process_access, membership: other, process_code: "AEC")

      expect(described_class.none?(membership)).to be(true)
    end
  end

  context "for a member habilitated on CERTDC and AEC" do
    let(:membership) { create(:membership) }

    before do
      create(:process_access, membership: membership, process_code: "CERTDC")
      create(:process_access, membership: membership, process_code: "AEC")
    end

    # Code inventé : la règle ne dépend d'aucune valeur, et les vrais codes de flux sensibles
    # ne descendent pas dans ce dépôt, qui est public.
    it "covers those data streams only, and hands them as the filter" do
      expect(described_class.covers?(membership, "CERTDC")).to be(true)
      expect(described_class.covers?(membership, "DEMO_AUTRE")).to be(false)
      expect(described_class.filter(membership)).to contain_exactly("CERTDC", "AEC")
      expect(described_class.none?(membership)).to be(false)
    end
  end

  context "for a local administrator without habilitation" do
    let(:membership) { create(:membership, :local_administrator) }

    it "covers every data stream, and hands the upstream an empty filter" do
      expect(described_class.covers?(membership, "AEC")).to be(true)
      expect(described_class.filter(membership)).to eq([])
      expect(described_class.none?(membership)).to be(false)
    end
  end

  # Le cas qui distingue cette règle de « l'administrateur voit tout ».
  context "for a local administrator habilitated on CERTDC" do
    let(:membership) { create(:membership, :local_administrator) }

    before { create(:process_access, membership: membership, process_code: "CERTDC") }

    it "covers that data stream only, and hands it as the filter" do
      expect(described_class.covers?(membership, "CERTDC")).to be(true)
      expect(described_class.covers?(membership, "AEC")).to be(false)
      expect(described_class.filter(membership)).to contain_exactly("CERTDC")
    end
  end
end
