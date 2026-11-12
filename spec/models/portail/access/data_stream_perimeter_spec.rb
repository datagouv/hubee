# frozen_string_literal: true

require "rails_helper"

# Le rôle ne tranche que la liste vide : tout pour l'administrateur local, rien pour le membre.
RSpec.describe Portail::Access::DataStreamPerimeter do
  context "for a member without habilitation" do
    let(:membership) { create(:membership) }

    it "gives no access at all" do
      expect(described_class.none?(membership)).to be(true)
      expect(described_class.covers?(membership, "CERTDC")).to be(false)
    end
  end

  context "for a member habilitated on CERTDC and AEC" do
    let(:membership) { create(:membership) }

    before do
      create(:data_stream_access, membership: membership, data_stream_code: "CERTDC")
      create(:data_stream_access, membership: membership, data_stream_code: "AEC")
    end

    # Code inventé : la règle ne dépend d'aucune valeur, et les vrais codes de flux sensibles
    # ne descendent pas dans ce dépôt, qui est public.
    it "covers those data streams only" do
      expect(described_class.covers?(membership, "CERTDC")).to be(true)
      expect(described_class.covers?(membership, "DEMO_AUTRE")).to be(false)
      expect(described_class.none?(membership)).to be(false)
    end

    # Deux agents de la même organisation, chacun ses flux : le périmètre est celui du
    # rattachement, pas de l'organisation.
    it "ignores the habilitations of another membership of the organisation" do
      other = create(:membership, organization_link: membership.organization_link)
      create(:data_stream_access, membership: other, data_stream_code: "DEMO_AUTRE")

      expect(described_class.covers?(membership, "DEMO_AUTRE")).to be(false)
    end
  end

  context "for a local administrator without habilitation" do
    let(:membership) { create(:membership, :local_administrator) }

    it "covers every data stream" do
      expect(described_class.covers?(membership, "AEC")).to be(true)
      expect(described_class.none?(membership)).to be(false)
    end
  end

  # Le cas qui distingue cette règle de « l'administrateur voit tout ».
  context "for a local administrator habilitated on CERTDC" do
    let(:membership) { create(:membership, :local_administrator) }

    before { create(:data_stream_access, membership: membership, data_stream_code: "CERTDC") }

    it "covers that data stream only" do
      expect(described_class.covers?(membership, "CERTDC")).to be(true)
      expect(described_class.covers?(membership, "AEC")).to be(false)
    end
  end
end
