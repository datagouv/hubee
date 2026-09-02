# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Agents::Create::CreateMemberships do
  subject(:result) { described_class.call(payload: payload, agent: agent, organization_links: organization_links) }

  let(:agent) { create(:agent) }
  let(:link) { create(:organization_link) }
  let(:organization_links) { {link.siret => link} }
  let(:payload) do
    API::AgentPayload.new(memberships: [
      {siret: link.siret, insee_code: link.insee_code, role: "local_administrator",
       job_title: "DGS", phone_number: "0123456789"}
    ])
  end

  it "attaches the agent with its role" do
    expect(result).to be_success
    expect(result.memberships).to contain_exactly(
      have_attributes(agent: agent, organization_link: link, role: "local_administrator", job_title: "DGS")
    )
  end

  it "attaches the agent to several organizations in one call" do
    other_link = create(:organization_link)
    organization_links[other_link.siret] = other_link
    payload.memberships << API::MembershipPayload.new(siret: other_link.siret, insee_code: other_link.insee_code,
      role: "member")

    expect(result).to be_success
    expect(result.memberships.map(&:organization_link)).to contain_exactly(link, other_link)
  end

  it "refuses what the model refuses, naming the indexed field" do
    payload.memberships.first.phone_number = "pas-un-numero"

    expect(result).to be_failure
    expect(result.error).to eq(:invalid_payload)
    expect(result.fields).to have_key(:"memberships[0].phone_number")
  end

  it "refuses a job title over the model's length limit, naming the indexed field" do
    payload.memberships.first.job_title = "a" * 256

    expect(result).to be_failure
    expect(result.error).to eq(:invalid_payload)
    expect(result.fields).to have_key(:"memberships[0].job_title")
  end
end
