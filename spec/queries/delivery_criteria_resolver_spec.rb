# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeliveryCriteriaResolver do
  describe ".resolve" do
    let(:data_stream) { create(:data_stream) }

    it "returns an ActiveRecord relation" do
      result = described_class.resolve({}, data_stream)
      expect(result).to be_a(ActiveRecord::Relation)
    end

    context "with siret criteria" do
      let(:org1) { create(:organization, siret: "13002526500013") }
      let(:org2) { create(:organization, siret: "11000601200010") }
      let(:org3) { create(:organization, siret: "99999999999999") }

      let!(:sub1) { create(:subscription, data_stream: data_stream, organization: org1, can_read: true) }
      let!(:sub2) { create(:subscription, data_stream: data_stream, organization: org2, can_read: true) }
      let!(:sub3) { create(:subscription, data_stream: data_stream, organization: org3, can_read: false, can_write: true) }

      it "resolves single siret string" do
        criteria = {"siret" => "13002526500013"}
        result = described_class.resolve(criteria, data_stream)
        expect(result).to contain_exactly(sub1)
      end

      it "resolves siret array" do
        criteria = {"siret" => ["13002526500013", "11000601200010"]}
        result = described_class.resolve(criteria, data_stream)
        expect(result).to contain_exactly(sub1, sub2)
      end

      it "filters out subscriptions without can_read" do
        criteria = {"siret" => ["13002526500013", "99999999999999"]}
        result = described_class.resolve(criteria, data_stream)
        expect(result).to contain_exactly(sub1)
      end

      it "returns empty relation when no matching siret" do
        criteria = {"siret" => "00000000000000"}
        result = described_class.resolve(criteria, data_stream)
        expect(result).to be_empty
      end
    end

    context "with empty or nil criteria" do
      it "returns empty relation for nil criteria" do
        result = described_class.resolve(nil, data_stream)
        expect(result).to be_empty
        expect(result).to be_a(ActiveRecord::Relation)
      end

      it "returns empty relation for empty hash" do
        result = described_class.resolve({}, data_stream)
        expect(result).to be_empty
        expect(result).to be_a(ActiveRecord::Relation)
      end

      it "returns empty relation for empty siret array" do
        result = described_class.resolve({"siret" => []}, data_stream)
        expect(result).to be_empty
      end
    end

    context "scoping to data_stream" do
      let(:other_stream) { create(:data_stream) }
      let(:org) { create(:organization, siret: "13002526500013") }
      let!(:sub_this_stream) { create(:subscription, data_stream: data_stream, organization: org, can_read: true) }
      let!(:sub_other_stream) { create(:subscription, data_stream: other_stream, organization: org, can_read: true) }

      it "only returns subscriptions for given data_stream" do
        criteria = {"siret" => "13002526500013"}
        result = described_class.resolve(criteria, data_stream)
        expect(result).to contain_exactly(sub_this_stream)
      end
    end
  end
end
