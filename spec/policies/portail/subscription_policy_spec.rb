# frozen_string_literal: true

require "rails_helper"

# La configuration des abonnements regarde l'administrateur local seul, et ses habilitations par
# flux n'y changent rien : elles bornent la lecture des télédossiers, pas celle des abonnements.
# L'organisation servie est vérifiée comme pour les télédossiers : l'amont est un tiers.
RSpec.describe Portail::SubscriptionPolicy do
  def scope(*subscriptions) = described_class::Scope.new(membership, subscriptions).resolve

  def index? = described_class.new(membership, Portail::Subscription).index?

  context "for a member habilitated on CERTDC" do
    let(:membership) { create(:membership) }

    before { create(:data_stream_access, membership: membership, data_stream_code: "CERTDC") }

    describe "#index?" do
      it "refuses the list" do
        expect(index?).to be(false)
      end
    end

    describe "Scope#resolve" do
      it "keeps nothing, even on the habilitated data stream" do
        subscription = build(:portail_subscription, membership: membership)

        expect(scope(subscription)).to be_empty
      end
    end
  end

  context "for a member without habilitation" do
    let(:membership) { create(:membership) }

    describe "#index?" do
      it "refuses the list" do
        expect(index?).to be(false)
      end
    end

    describe "Scope#resolve" do
      it "keeps nothing" do
        subscription = build(:portail_subscription, membership: membership)

        expect(scope(subscription)).to be_empty
      end
    end
  end

  context "for a local administrator habilitated on CERTDC" do
    let(:membership) { create(:membership, :local_administrator) }

    before { create(:data_stream_access, membership: membership, data_stream_code: "CERTDC") }

    describe "#index?" do
      it "accepts the list" do
        expect(index?).to be(true)
      end
    end

    describe "Scope#resolve" do
      it "keeps every data stream of the organisation, drops another organisation" do
        habilitated = build(:portail_subscription, membership: membership)
        other_stream = build(:portail_subscription, id: "sub-2", data_stream_code: "AEC", membership: membership)
        other_organisation = build(:portail_subscription, :of_another_organisation, id: "sub-3")

        expect(scope(habilitated, other_stream, other_organisation)).to eq([habilitated, other_stream])
      end
    end
  end

  context "for a local administrator without habilitation" do
    let(:membership) { create(:membership, :local_administrator) }

    describe "#index?" do
      it "accepts the list" do
        expect(index?).to be(true)
      end
    end

    describe "Scope#resolve" do
      it "keeps every data stream of the organisation, drops another organisation" do
        kept = build(:portail_subscription, membership: membership)
        other_organisation = build(:portail_subscription, :of_another_organisation, id: "sub-2")

        expect(scope(kept, other_organisation)).to eq([kept])
      end
    end
  end
end
