# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessAccess, type: :model do
  describe "associations" do
    subject { build(:process_access) }

    it { is_expected.to belong_to(:membership) }
  end

  describe "process_code" do
    it "keeps the code exactly as the V1 referential spells it" do
      expect(create(:process_access, process_code: "certdc-v2").process_code)
        .to eq("certdc-v2")
      expect(create(:process_access, process_code: "  CERTDC  ").process_code)
        .to eq("CERTDC")
    end

    it "refuses a code carrying an inner space" do
      expect(build(:process_access, process_code: "CERT DC")).not_to be_valid
    end

    it "bounds the code length" do
      expect(build(:process_access, process_code: "A" * 100)).to be_valid
      expect(build(:process_access, process_code: "A" * 101)).not_to be_valid
    end

    it "tells two codes apart when only their case differs" do
      membership = create(:membership)
      create(:process_access, membership:, process_code: "CERTDC")

      expect(build(:process_access, membership:, process_code: "certdc")).to be_valid
      expect(build(:process_access, membership:, process_code: "CERTDC")).not_to be_valid
    end
  end

  describe "cascade" do
    # La garantie est en base : `delete_all` ne déclenche aucun callback, et c'est
    # précisément le cas qu'un `dependent: :destroy` laisserait filer.
    it "disappears with the membership it was granted under" do
      process_access = create(:process_access)

      Membership.where(id: process_access.membership_id).delete_all

      expect(ProcessAccess.exists?(process_access.id)).to be(false)
    end
  end

  describe "labels" do
    it "names the attribute in French" do
      expect(described_class.human_attribute_name(:process_code)).to eq("Code du processus")
    end
  end
end
