# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::Update do
  let(:api_client) { build_stubbed(:oauth_application, name: "systeme-interne") }
  let!(:agent) { create(:agent, email: "alice.martin@ville.fr") }

  describe ".call" do
    def update(**attributes)
      form = API::Internal::V1::AgentUpdateForm.new(agent:, **attributes)
      described_class.call(form:, api_client:, request_id: "req-1")
    end

    it "corrects the agent" do
      result = update(email: "alice.dupont@ville.fr", civility: "ms")

      expect(result).to be_success
      expect(agent.reload).to have_attributes(email: "alice.dupont@ville.fr", civility: "ms")
    end

    it "writes nothing when the payload is invalid" do
      result = update(email: "pas-une-adresse")

      expect(result).to be_failure
      expect(agent.reload.email).to eq("alice.martin@ville.fr")
      expect(Event.count).to eq(0)
    end

    it "refuses an address carried by another agent without writing" do
      create(:agent, email: "alice.dupont@ville.fr")

      result = update(email: "alice.dupont@ville.fr")

      expect(result).to be_failure
      expect(result.refusals).to eq([:email_taken])
      expect(agent.reload.email).to eq("alice.martin@ville.fr")
      expect(Event.count).to eq(0)
    end
  end
end
