# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Applicant do
  describe "#full_name" do
    it "joins both halves of the name" do
      expect(build(:portail_applicant).full_name).to eq("George DUBOIS")
    end

    it "leaves no stray space when a half is missing" do
      expect(build(:portail_applicant, first_name: nil).full_name).to eq("DUBOIS")
      expect(build(:portail_applicant, last_name: "").full_name).to eq("George")
    end

    # La chaîne vide laisse l'appelant décider de son repli.
    it "returns an empty string when both halves are missing" do
      expect(build(:portail_applicant, first_name: nil, last_name: "").full_name).to eq("")
    end
  end
end
