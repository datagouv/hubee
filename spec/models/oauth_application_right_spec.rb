# frozen_string_literal: true

require "rails_helper"

RSpec.describe OauthApplicationRight, type: :model do
  describe "associations" do
    subject { build(:oauth_application_right) }

    it { is_expected.to belong_to(:oauth_application).class_name("Doorkeeper::Application") }
  end

  describe "right" do
    it "accepts the right to register agents" do
      expect(build(:oauth_application_right, right: "internal:agents:create")).to be_valid
    end

    it "refuses a right the API does not know, such as a misspelt one" do
      right = build(:oauth_application_right, right: "internal:agents:craete")

      expect(right).not_to be_valid
      expect(right.errors.details[:right]).to eq([{error: :inclusion, value: "internal:agents:craete"}])
    end

    it "grants a right only once to a client" do
      granted = create(:oauth_application_right)
      again = build(:oauth_application_right, oauth_application: granted.oauth_application)

      expect(again).not_to be_valid
      expect(again.errors.details[:right]).to eq([{error: :taken, value: "internal:agents:create"}])
    end
  end

  it "leaves with its client" do
    right = create(:oauth_application_right)

    right.oauth_application.destroy!

    expect(described_class.exists?(right.id)).to be(false)
  end
end
