# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Agents::Create::ValidatePayload do
  subject(:result) { described_class.call(payload: payload) }

  context "with a valid payload" do
    let(:payload) { instance_double(API::AgentPayload, valid?: true) }

    it { is_expected.to be_success }
  end

  context "with an invalid payload" do
    let(:payload) { API::AgentPayload.new(email: nil) }

    it "fails carrying the faulty fields" do
      expect(result).to be_failure
      expect(result.error).to eq(:invalid_payload)
      expect(result.fields).to have_key(:email)
    end
  end
end
