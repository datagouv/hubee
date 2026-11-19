# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::Destroy::Remove do
  let(:api_client) { create(:oauth_application, name: "systeme-interne") }
  let!(:agent) { create(:agent, email: "alice.martin@ville.fr") }
  # Le cas standard : un membre habilité sur deux flux.
  let!(:membership) do
    create(:membership, agent:, organization_link: create(:organization_link, siret: "21750056000016", insee_code: "75056")).tap do
      create(:data_stream_access, membership: it, data_stream_code: "DECES")
      create(:data_stream_access, membership: it, data_stream_code: "CERTDC")
    end
  end
  let!(:administrator_membership) do
    create(:membership, agent:, role: "local_administrator",
      organization_link: create(:organization_link, siret: "13002526500013", insee_code: "75101"))
  end

  describe ".call" do
    def remove
      described_class.call(agent:, api_client:, request_id: "req-1")
    end

    it "deletes the agent with his memberships, habilitations and sessions" do
      provider_session = create(:provider_session, membership:)

      result = remove

      expect(result).to be_success
      expect(Agent.exists?(agent.id)).to be(false)
      expect(Membership.where(agent_id: agent.id)).to be_empty
      expect(DataStreamAccess.where(membership_id: membership.id)).to be_empty
      expect(ProviderSession.exists?(provider_session.id)).to be(false)
    end

    it "keeps the organisation links, which serve other agents" do
      remove

      expect(OrganizationLink.where(id: [membership.organization_link_id, administrator_membership.organization_link_id]).count).to eq(2)
    end

    it "keeps the earlier traces of the agent" do
      earlier = Event.create!(eventable: agent, event_type: "agent.created", metadata: {"email" => "alice.martin@ville.fr"})

      remove

      expect(Event.exists?(earlier.id)).to be(true)
    end

    it "writes the full trace" do
      remove

      expect(Event.find_by!(event_type: "agent.deleted")).to have_attributes(
        eventable_type: "Agent",
        eventable_id: agent.id,
        metadata: {
          "api_client" => "systeme-interne",
          "api_client_uid" => api_client.uid,
          "request_id" => "req-1",
          "email" => "alice.martin@ville.fr",
          "memberships" => [
            {"siret" => "13002526500013", "insee_code" => "75101", "role" => "local_administrator", "data_stream_codes" => []},
            {"siret" => "21750056000016", "insee_code" => "75056", "role" => "member", "data_stream_codes" => ["CERTDC", "DECES"]}
          ]
        }
      )
    end

    # Le controller a lu l'agent, ses rattachements et leurs habilitations ; un autre appel les change avant
    # le verrou. La trace doit décrire ce que la transaction supprime.
    it "traces the state read under the lock, not the one loaded before" do
      loaded = Agent.includes(memberships: %i[organization_link data_stream_accesses]).find(agent.id)
      loaded.memberships.each(&:data_stream_codes)
      administrator_membership.update!(role: "member")
      create(:data_stream_access, membership: administrator_membership, data_stream_code: "AEC")
      attached = create(:membership, agent:, organization_link: create(:organization_link, siret: "34293330900013", insee_code: "33063"))
      create(:data_stream_access, membership: attached, data_stream_code: "DECES")

      described_class.call(agent: loaded, api_client:, request_id: "req-1")

      expect(Event.find_by!(event_type: "agent.deleted").metadata["memberships"]).to eq(
        [
          {"siret" => "13002526500013", "insee_code" => "75101", "role" => "member", "data_stream_codes" => ["AEC"]},
          {"siret" => "21750056000016", "insee_code" => "75056", "role" => "member", "data_stream_codes" => ["CERTDC", "DECES"]},
          {"siret" => "34293330900013", "insee_code" => "33063", "role" => "member", "data_stream_codes" => ["DECES"]}
        ]
      )
      expect(Membership.where(agent_id: agent.id)).to be_empty
    end

    it "deletes a membership attached after the agent was read, instead of failing on the foreign key" do
      loaded = Agent.includes(memberships: %i[organization_link data_stream_accesses]).find(agent.id)
      create(:membership, agent:, organization_link: create(:organization_link, siret: "34293330900013", insee_code: "33063"), role: "local_administrator")

      expect(described_class.call(agent: loaded, api_client:, request_id: "req-1")).to be_success

      expect(Agent.exists?(agent.id)).to be(false)
      expect(Membership.where(agent_id: agent.id)).to be_empty
    end

    it "deletes nothing when the trace fails" do
      provider_session = create(:provider_session, membership:)
      expect(Event).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect { remove }.to raise_error(ActiveRecord::RecordInvalid)

      expect(Agent.exists?(agent.id)).to be(true)
      expect(agent.memberships.count).to eq(2)
      expect(membership.data_stream_accesses.count).to eq(2)
      expect(ProviderSession.exists?(provider_session.id)).to be(true)
      expect(Event.count).to eq(0)
    end
  end
end
