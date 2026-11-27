# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::Update::CheckEmailAvailability do
  describe ".call" do
    let!(:agent) { create(:agent, email: "alice.martin@ville.fr") }

    def check(**attributes)
      form = API::Internal::V1::AgentUpdateForm.new(agent:, **attributes).tap(&:validate)
      described_class.call(form:)
    end

    it "refuses an address carried by another agent" do
      create(:agent, email: "alice.dupont@ville.fr")

      result = check(email: "Alice.Dupont@ville.fr")

      expect(result).to be_success
      expect(result.refusals).to eq([:email_taken])
    end

    it "accepts a free address" do
      expect(check(email: "alice.dupont@ville.fr").refusals).to be_nil
    end

    it "accepts the address of the agent himself in another case" do
      expect(check(email: "ALICE.MARTIN@ville.fr").refusals).to be_nil
    end

    it "asks nothing when the email is not received" do
      expect(check(civility: "ms").refusals).to be_nil
    end

    it "leaves an invalid address to its own reason" do
      expect(check(email: "pas-une-adresse").refusals).to be_nil
    end
  end
end
