# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Agents::Create do
  subject(:result) { described_class.call(payload: payload, api_client: "hub-api", request_id: "req-1") }

  let(:payload) do
    API::AgentPayload.new(
      email: "alice.martin@ville.fr", first_name: "Alice", last_name: "Martin",
      memberships: [{siret: "21750056000016", insee_code: "001", role: "member"}]
    )
  end

  before do
    create(:organization_link, siret: "21750056000016", insee_code: "001")
  end

  it "creates the agent, its membership and their traces in one call" do
    expect { result }.to change(Agent, :count).by(1)
      .and change(Membership, :count).by(1)
      .and change(Event, :count).by(2)

    expect(result).to be_success
  end

  # Un agent créé au pluriel écrit autant de rattachements et de traces de
  # rattachement qu'il y a d'entrées — l'invariant reste tout ou rien.
  it "creates several memberships and one membership trace per entry" do
    create(:organization_link, siret: "35600000000048", insee_code: "002")
    payload.memberships << API::MembershipPayload.new(siret: "35600000000048", insee_code: "002", role: "member")

    expect { result }.to change(Agent, :count).by(1)
      .and change(Membership, :count).by(2)
      .and change(Event, :count).by(1 + 2)

    expect(result).to be_success
  end

  # L'invariant du ticket : un appel invalide n'écrit rien — pas d'agent sans sa trace.
  it "writes nothing at all when the trace cannot be written" do
    allow(Event).to receive(:record!).and_raise(ActiveRecord::RecordInvalid)

    expect { result }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Agent.count).to eq(0)
    expect(Membership.count).to eq(0)
  end

  it "writes nothing when the payload is invalid" do
    payload.email = nil

    expect { result }.not_to change(Agent, :count)
    expect(result.error).to eq(:invalid_payload)
  end
end
