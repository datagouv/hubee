# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeliveryCriteria::Resolver do
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

      it "resolves siret array (implicit IN)" do
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

    context "with organization_id criteria" do
      let(:org) { create(:organization) }
      let!(:subscription) { create(:subscription, data_stream: data_stream, organization: org, can_read: true) }

      it "resolves single organization_id" do
        criteria = {"organization_id" => org.id}
        result = described_class.resolve(criteria, data_stream)
        expect(result).to contain_exactly(subscription)
      end

      it "resolves organization_id array" do
        org2 = create(:organization)
        sub2 = create(:subscription, data_stream: data_stream, organization: org2, can_read: true)

        criteria = {"organization_id" => [org.id, org2.id]}
        result = described_class.resolve(criteria, data_stream)
        expect(result).to contain_exactly(subscription, sub2)
      end
    end

    context "with subscription_id criteria" do
      let!(:subscription) { create(:subscription, data_stream: data_stream, can_read: true) }

      it "resolves single subscription_id" do
        criteria = {"subscription_id" => subscription.id}
        result = described_class.resolve(criteria, data_stream)
        expect(result).to contain_exactly(subscription)
      end

      it "filters out subscriptions without can_read" do
        sub_no_read = create(:subscription, data_stream: data_stream, can_read: false, can_write: true)
        criteria = {"subscription_id" => sub_no_read.id}
        result = described_class.resolve(criteria, data_stream)
        expect(result).to be_empty
      end

      it "resolves subscription_id array" do
        sub2 = create(:subscription, data_stream: data_stream, can_read: true)

        criteria = {"subscription_id" => [subscription.id, sub2.id]}
        result = described_class.resolve(criteria, data_stream)
        expect(result).to contain_exactly(subscription, sub2)
      end
    end

    context "with _or operator" do
      let(:org1) { create(:organization, siret: "13002526500013") }
      let(:org2) { create(:organization, siret: "11000601200010") }
      let!(:sub1) { create(:subscription, data_stream: data_stream, organization: org1, can_read: true) }
      let!(:sub2) { create(:subscription, data_stream: data_stream, organization: org2, can_read: true) }

      it "returns union of results" do
        criteria = {
          "_or" => [
            {"siret" => "13002526500013"},
            {"siret" => "11000601200010"}
          ]
        }
        result = described_class.resolve(criteria, data_stream)
        expect(result).to contain_exactly(sub1, sub2)
      end

      it "deduplicates results" do
        criteria = {
          "_or" => [
            {"siret" => "13002526500013"},
            {"organization_id" => org1.id}
          ]
        }
        result = described_class.resolve(criteria, data_stream)
        expect(result).to contain_exactly(sub1)
      end
    end

    context "with _and operator" do
      let(:org) { create(:organization, siret: "13002526500013") }
      let!(:subscription) { create(:subscription, data_stream: data_stream, organization: org, can_read: true) }

      it "returns intersection of results" do
        criteria = {
          "_and" => [
            {"siret" => "13002526500013"},
            {"organization_id" => org.id}
          ]
        }
        result = described_class.resolve(criteria, data_stream)
        expect(result).to contain_exactly(subscription)
      end

      it "returns empty when no intersection" do
        org2 = create(:organization, siret: "11000601200010")
        create(:subscription, data_stream: data_stream, organization: org2, can_read: true)

        criteria = {
          "_and" => [
            {"siret" => "13002526500013"},
            {"siret" => "11000601200010"}
          ]
        }
        result = described_class.resolve(criteria, data_stream)
        expect(result).to be_empty
      end
    end

    context "with implicit AND (multiple keys)" do
      let(:org) { create(:organization, siret: "13002526500013") }
      let!(:subscription) { create(:subscription, data_stream: data_stream, organization: org, can_read: true) }

      it "treats multiple keys as AND" do
        criteria = {
          "siret" => "13002526500013",
          "organization_id" => org.id
        }
        result = described_class.resolve(criteria, data_stream)
        expect(result).to contain_exactly(subscription)
      end

      it "returns empty when criteria don't all match" do
        org2 = create(:organization)

        criteria = {
          "siret" => "13002526500013",
          "organization_id" => org2.id
        }
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
    end

    context "with invalid criteria" do
      it "raises Invalid for unknown operator" do
        criteria = {"_unknown" => []}
        expect {
          described_class.resolve(criteria, data_stream)
        }.to raise_error(DeliveryCriteriaValidator::Invalid, /unknown.*_unknown/i)
      end

      it "raises Invalid for unsupported criterion" do
        criteria = {"unknown_field" => "value"}
        expect {
          described_class.resolve(criteria, data_stream)
        }.to raise_error(DeliveryCriteriaValidator::Invalid, /unsupported.*unknown_field/i)
      end

      it "raises Invalid when nesting depth exceeds limit (max 2)" do
        deeply_nested = {"siret" => "13002526500013"}
        3.times { deeply_nested = {"_or" => [deeply_nested]} }

        expect {
          described_class.resolve(deeply_nested, data_stream)
        }.to raise_error(DeliveryCriteriaValidator::Invalid, /nesting depth/i)
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

    context "encapsulation" do
      it "hides internal criterion classes" do
        expect {
          DeliveryCriteria::Resolver::SiretCriterion
        }.to raise_error(NameError)
      end
    end
  end
end
