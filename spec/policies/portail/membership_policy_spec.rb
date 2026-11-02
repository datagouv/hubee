# frozen_string_literal: true

require "rails_helper"

# La liste des agents regarde l'administrateur local seul, et ses habilitations par flux n'y
# changent rien. Les rattachements sont locaux : le scope est la borne elle-même, et une
# organisation qui partage le SIRET n'en fait pas partie.
RSpec.describe Portail::MembershipPolicy do
  def scope = described_class::Scope.new(membership, Membership.all).resolve

  def index? = described_class.new(membership, Membership).index?

  def colleague_of(membership) = create(:membership, organization_link: membership.organization_link)

  def same_siret_outsider_of(membership)
    link = create(:organization_link, siret: membership.organization_link.siret)
    create(:membership, organization_link: link)
  end

  context "for a member habilitated on CERTDC" do
    let(:membership) { create(:membership) }

    before { create(:data_stream_access, membership: membership, data_stream_code: "CERTDC") }

    describe "#index?" do
      it "refuses the list" do
        expect(index?).to be(false)
      end
    end

    describe "Scope#resolve" do
      it "keeps nothing, not even the member's own organisation" do
        colleague_of(membership)

        expect(scope).to be_empty
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
        colleague_of(membership)

        expect(scope).to be_empty
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
      it "keeps the organisation's memberships, drops one sharing the SIRET" do
        colleague = colleague_of(membership)
        same_siret_outsider_of(membership)

        expect(scope).to contain_exactly(membership, colleague)
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
      it "keeps the organisation's memberships, drops one sharing the SIRET" do
        colleague = colleague_of(membership)
        same_siret_outsider_of(membership)

        expect(scope).to contain_exactly(membership, colleague)
      end
    end
  end
end
