# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Agents::Create::RecordTraces do
  subject(:result) do
    described_class.call(agent: agent, memberships: memberships, api_client: "hub-api", request_id: "req-1")
  end

  let(:agent) { create(:agent, email: "alice.martin@ville.fr", first_name: "Alice", last_name: "Martin", civility: "ms") }
  let(:link) { create(:organization_link) }
  let(:memberships) do
    [create(:membership, agent: agent, organization_link: link, role: "local_administrator",
      job_title: "Chargée de projet", phone_number: nil)]
  end

  it "records who was created, where, with which power, on whose order" do
    expect { result }.to change(Event, :count).by(2)

    membership_trace = Event.find_by(event_type: "membership.created")
    expect(membership_trace.metadata).to eq(
      "api_client" => "hub-api",
      "request_id" => "req-1",
      "subject" => {
        "email" => "alice.martin@ville.fr",
        "siret" => link.siret,
        "insee_code" => link.insee_code,
        "role" => "local_administrator",
        "job_title" => "Chargée de projet",
        "phone_number" => nil
      }
    )
  end

  it "records the agent trace with its full state, nulls included" do
    result

    agent_trace = Event.find_by(event_type: "agent.created")
    expect(agent_trace.metadata).to eq(
      "api_client" => "hub-api",
      "request_id" => "req-1",
      "subject" => {
        "email" => "alice.martin@ville.fr",
        "first_name" => "Alice",
        "last_name" => "Martin",
        "civility" => "ms"
      }
    )
  end

  it "records one trace per membership" do
    other_link = create(:organization_link)
    memberships << create(:membership, agent: agent, organization_link: other_link, role: "member")

    expect { result }.to change(Event, :count).by(3)
    expect(Event.where(event_type: "membership.created").count).to eq(2)
  end
end
