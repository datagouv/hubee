# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Agents::Create::CreateAgent do
  subject(:result) { described_class.call(payload: payload) }

  let(:payload) do
    API::AgentPayload.new(email: "alice.martin@ville.fr", first_name: "Alice", last_name: "Martin", civility: "ms")
  end

  it "creates the agent from the payload identity" do
    expect(result).to be_success
    expect(result.agent).to have_attributes(
      email: "alice.martin@ville.fr", first_name: "Alice", last_name: "Martin", civility: "ms"
    )
  end

  it "refuses an address another agent already holds" do
    create(:agent, email: "alice.martin@ville.fr")

    expect(result).to be_failure
    expect(result.error).to eq(:email_taken)
  end

  it "refuses an address a concurrent call just took" do
    allow(Agent).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

    expect(result).to be_failure
    expect(result.error).to eq(:email_taken)
  end
end
