# frozen_string_literal: true

require "rails_helper"

# La configuration des abonnements regarde l'administrateur local seul, et ses habilitations par
# flux n'y changent rien : elles bornent la lecture des télédossiers, pas celle des abonnements.
# L'organisation servie est vérifiée comme pour les télédossiers : l'amont est un tiers.
RSpec.describe Portail::SubscriptionPolicy do
  def scope(*subscriptions) = described_class::Scope.new(membership, subscriptions).resolve

  def index? = described_class.new(membership, Portail::Subscription).index?

  def show?(subscription) = described_class.new(membership, subscription).show?

  context "for a member habilitated on CERTDC" do
    let(:membership) { create(:membership) }

    before { create(:data_stream_access, membership: membership, data_stream_code: "CERTDC") }

    describe "#index?" do
      it "refuses the list" do
        expect(index?).to be(false)
      end
    end

    describe "#show?" do
      it "refuses a subscription of its own organisation" do
        expect(show?(build(:portail_subscription, membership: membership))).to be(false)
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

    describe "#show?" do
      it "refuses a subscription of its own organisation" do
        expect(show?(build(:portail_subscription, membership: membership))).to be(false)
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

    describe "#show?" do
      it "accepts a subscription of its organisation, refuses another organisation" do
        expect(show?(build(:portail_subscription, membership: membership))).to be(true)
        expect(show?(build(:portail_subscription, :of_another_organisation))).to be(false)
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

    describe "#show?" do
      it "accepts a subscription of its organisation, refuses another organisation" do
        expect(show?(build(:portail_subscription, membership: membership))).to be(true)
        expect(show?(build(:portail_subscription, :of_another_organisation))).to be(false)
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

  # Le secret d'un abonnement API : la règle du détail, et le mode API, seul à avoir un client OAuth.
  # La matrice rôle × habilitation entière, aucune case ne se déduisant d'une autre.
  describe "#consult_credentials?" do
    def consult_credentials?(subscription) = described_class.new(membership, subscription).consult_credentials?

    def api_subscription(**) = build(:portail_subscription, membership: membership, access_mode: "api", **)

    context "for a member habilitated on CERTDC" do
      let(:membership) { create(:membership) }

      before { create(:data_stream_access, membership: membership, data_stream_code: "CERTDC") }

      it "refuses the credentials of an API subscription of its own organisation" do
        expect(consult_credentials?(api_subscription)).to be(false)
      end
    end

    context "for a member without habilitation" do
      let(:membership) { create(:membership) }

      it "refuses the credentials of an API subscription of its own organisation" do
        expect(consult_credentials?(api_subscription)).to be(false)
      end
    end

    context "for a local administrator habilitated on CERTDC" do
      let(:membership) { create(:membership, :local_administrator) }

      before { create(:data_stream_access, membership: membership, data_stream_code: "CERTDC") }

      it "allows the credentials of an API subscription of its own organisation" do
        expect(consult_credentials?(api_subscription)).to be(true)
      end
    end

    context "for a local administrator without habilitation" do
      let(:membership) { create(:membership, :local_administrator) }

      it "allows the credentials of an API subscription of its own organisation" do
        expect(consult_credentials?(api_subscription)).to be(true)
      end

      it "refuses a portal subscription, which has no OAuth client" do
        expect(consult_credentials?(api_subscription(access_mode: "portal"))).to be(false)
      end

      it "refuses a subscription whose access mode is unset" do
        expect(consult_credentials?(api_subscription(access_mode: nil))).to be(false)
      end

      it "refuses an API subscription the upstream served for another organisation" do
        subscription = build(:portail_subscription, :of_another_organisation, access_mode: "api")

        expect(consult_credentials?(subscription)).to be(false)
      end
    end
  end
end
