# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::MembershipPayload do
  subject(:payload) { described_class.new(attributes) }

  let(:attributes) do
    {siret: "21750056000016", insee_code: "001", role: "local_administrator",
     job_title: "Officier d'état civil", phone_number: "+33123456789"}
  end

  it "accepts a complete membership" do
    expect(payload).to be_valid
  end

  it "accepts a membership without the optional attributes" do
    attributes.delete(:job_title)
    attributes.delete(:phone_number)

    expect(payload).to be_valid
  end

  %i[siret insee_code role].each do |required|
    it "refuses a membership without #{required}" do
      attributes[required] = nil

      expect(payload).not_to be_valid
      expect(payload.errors).to be_of_kind(required, :blank)
    end
  end

  it "refuses a siret that is not 14 digits" do
    attributes[:siret] = "123"

    expect(payload).not_to be_valid
  end

  it "refuses a role outside the closed list" do
    attributes[:role] = "national_administrator"

    expect(payload).not_to be_valid
  end
end
