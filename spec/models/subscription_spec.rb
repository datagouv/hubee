# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:data_stream) }
    it { is_expected.to belong_to(:organization) }
  end

  describe "validations" do
    subject { build(:subscription) }

    it { is_expected.to validate_presence_of(:permission_type) }
    it { is_expected.to validate_uniqueness_of(:data_stream_id).scoped_to(:organization_id) }
  end

  describe "enum permission_type" do
    it { is_expected.to define_enum_for(:permission_type).with_values(read: "read", write: "write", read_write: "read_write").backed_by_column_of_type(:string) }
  end

  describe "database constraints" do
    it "cascades delete when data_stream is destroyed" do
      subscription = create(:subscription)
      data_stream = subscription.data_stream

      expect { data_stream.destroy! }.to change(Subscription, :count).by(-1)
    end

    it "cascades delete when organization is destroyed" do
      subscription = create(:subscription)
      organization = subscription.organization

      expect { organization.destroy! }.to change(Subscription, :count).by(-1)
    end

    it "enforces unique constraint on data_stream_id and organization_id" do
      subscription1 = create(:subscription)
      subscription2 = build(:subscription, data_stream: subscription1.data_stream, organization: subscription1.organization)

      expect { subscription2.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "uuid" do
    it "generates UUID automatically" do
      subscription = create(:subscription)
      expect(subscription.uuid).to be_present
      expect(subscription.uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "ensures UUID uniqueness" do
      subscription1 = create(:subscription)
      subscription2 = create(:subscription)
      expect(subscription1.uuid).not_to eq(subscription2.uuid)
    end
  end
end
