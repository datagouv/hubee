# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataStreamAccess, type: :model do
  describe "associations" do
    subject { build(:data_stream_access) }

    it { is_expected.to belong_to(:membership) }
  end

  describe "data_stream_code" do
    it "keeps the code exactly as the V1 referential spells it" do
      expect(create(:data_stream_access, data_stream_code: "certdc-v2").data_stream_code)
        .to eq("certdc-v2")
      expect(create(:data_stream_access, data_stream_code: "  CERTDC  ").data_stream_code)
        .to eq("CERTDC")
    end

    it "refuses a code carrying an inner space" do
      expect(build(:data_stream_access, data_stream_code: "CERT DC")).not_to be_valid
    end

    it "bounds the code length" do
      expect(build(:data_stream_access, data_stream_code: "A" * 100)).to be_valid
      expect(build(:data_stream_access, data_stream_code: "A" * 101)).not_to be_valid
    end

    it "tells two codes apart when only their case differs" do
      membership = create(:membership)
      create(:data_stream_access, membership:, data_stream_code: "CERTDC")

      expect(build(:data_stream_access, membership:, data_stream_code: "certdc")).to be_valid
      expect(build(:data_stream_access, membership:, data_stream_code: "CERTDC")).not_to be_valid
    end
  end

  describe "cascade" do
    # La garantie est en base : `delete_all` ne déclenche aucun callback, et c'est
    # précisément le cas qu'un `dependent: :destroy` laisserait filer.
    it "disappears with the membership it was granted under" do
      data_stream_access = create(:data_stream_access)

      Membership.where(id: data_stream_access.membership_id).delete_all

      expect(DataStreamAccess.exists?(data_stream_access.id)).to be(false)
    end
  end

  describe "labels" do
    it "names the attribute in French" do
      expect(described_class.human_attribute_name(:data_stream_code)).to eq("Code du flux")
    end
  end
end
