# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::Agents::Create::EnsureNoRefusal do
  describe ".call" do
    it "lets a request without any reason through" do
      form = build(:api_internal_agent_form).tap(&:validate)

      expect(described_class.call(form:)).to be_success
    end

    it "stops a request with an invalid field" do
      form = build(:api_internal_agent_form, email: "").tap(&:validate)

      expect(described_class.call(form:)).to be_failure
    end

    it "stops a request refused by a check" do
      form = build(:api_internal_agent_form).tap(&:validate)

      expect(described_class.call(form:, refusals: [:already_attached])).to be_failure
    end

    it "stops a request a check could not conclude" do
      form = build(:api_internal_agent_form).tap(&:validate)

      expect(described_class.call(form:, unavailable: true)).to be_failure
    end
  end
end
