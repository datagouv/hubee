# frozen_string_literal: true

require "rails_helper"

# La règle rôle × habilitation est éprouvée dans le spec de Portail::ReadingPerimeter. Ici, on
# constate que la policy l'applique à ce que l'amont a servi, sur la liste et sur le détail, et
# qu'elle vérifie aussi l'organisation : l'amont est un tiers, son filtre n'est pas tenu pour acquis.
RSpec.describe Portail::DeliveryPolicy do
  # Par défaut, une démarche de l'organisation du rattachement : ce que l'amont doit servir.
  def delivery_on(code, recipient: own_organisation)
    build(:portail_delivery, data_stream_code: code, recipient: recipient)
  end

  def own_organisation
    link = membership.organization_link
    build(:portail_recipient, siret: link.siret, insee_code: link.insee_code)
  end

  let(:other_organisation) { build(:portail_recipient, siret: "13002526500013", insee_code: "75056") }

  describe "Scope#resolve" do
    def scope(*deliveries) = described_class::Scope.new(membership, deliveries).resolve

    context "for a member without habilitation" do
      let(:membership) { create(:membership) }

      it "keeps nothing" do
        expect(scope(delivery_on("CERTDC"))).to be_empty
      end
    end

    context "for a member habilitated on CERTDC" do
      let(:membership) { create(:membership) }

      before { create(:process_access, membership: membership, process_code: "CERTDC") }

      it "keeps the deliveries on CERTDC for the organisation, and drops the others" do
        kept = delivery_on("CERTDC")

        expect(scope(kept, delivery_on("AEC"), delivery_on("CERTDC", recipient: other_organisation)))
          .to eq([kept])
      end
    end

    context "for a local administrator without habilitation" do
      let(:membership) { create(:membership, :local_administrator) }

      it "keeps every data stream of the organisation, and drops another organisation" do
        kept = [delivery_on("CERTDC"), delivery_on("AEC")]

        expect(scope(*kept, delivery_on("AEC", recipient: other_organisation))).to eq(kept)
      end
    end

    context "for a local administrator habilitated on CERTDC" do
      let(:membership) { create(:membership, :local_administrator) }

      before { create(:process_access, membership: membership, process_code: "CERTDC") }

      it "keeps only CERTDC" do
        kept = delivery_on("CERTDC")

        expect(scope(kept, delivery_on("AEC"))).to eq([kept])
      end
    end
  end

  describe "#show?" do
    def policy_on(code, recipient: own_organisation)
      described_class.new(membership, delivery_on(code, recipient: recipient))
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

      it "accepts a delivery on CERTDC for the organisation" do
        expect(policy_on("CERTDC").show?).to be(true)
      end

      # Le trou que cette policy ferme : la liste ne montre pas cette démarche, mais son
      # identifiant suffirait à l'ouvrir.
      it "refuses a delivery on another data stream" do
        expect(policy_on("AEC").show?).to be(false)
      end

      # La requête amont porte déjà l'organisation ; ceci vérifie que l'amont l'a respectée.
      it "refuses a delivery of another organisation" do
        expect(policy_on("CERTDC", recipient: other_organisation).show?).to be(false)
      end
    end

    context "for a local administrator without habilitation" do
      let(:membership) { create(:membership, :local_administrator) }

      it "accepts a delivery on any data stream of the organisation" do
        expect(policy_on("AEC").show?).to be(true)
      end

      it "refuses a delivery of another organisation" do
        expect(policy_on("AEC", recipient: other_organisation).show?).to be(false)
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
