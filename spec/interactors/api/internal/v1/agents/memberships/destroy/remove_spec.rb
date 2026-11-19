# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::Memberships::Destroy::Remove do
  let(:api_client) { create(:oauth_application, name: "systeme-interne") }
  let(:agent) { create(:agent, email: "alice.martin@ville.fr") }
  # Le cas standard : un membre habilité sur deux flux.
  let!(:membership) do
    create(:membership, agent:, organization_link: create(:organization_link, siret: "21750056000016", insee_code: "75056")).tap do
      create(:data_stream_access, membership: it, data_stream_code: "DECES")
      create(:data_stream_access, membership: it, data_stream_code: "CERTDC")
    end
  end
  let!(:provider_session) { create(:provider_session, membership:) }

  describe ".call" do
    def remove
      described_class.call(membership:, api_client:, request_id: "req-1")
    end

    it "deletes the membership with its habilitations and its sessions" do
      result = remove

      expect(result).to be_success
      expect(Membership.exists?(membership.id)).to be(false)
      expect(DataStreamAccess.where(membership_id: membership.id)).to be_empty
      expect(ProviderSession.exists?(provider_session.id)).to be(false)
      expect(Agent.exists?(agent.id)).to be(true)
    end

    # Le controller a lu le rattachement ; un autre appel le modifie avant le verrou. La trace doit décrire
    # ce que la transaction supprime.
    it "traces the state read under the lock, not the one loaded before" do
      loaded = agent.memberships.includes(:organization_link, :data_stream_accesses).find(membership.id)
      loaded.data_stream_codes
      membership.update!(role: "local_administrator")
      membership.data_stream_accesses.find_by!(data_stream_code: "DECES").destroy!

      described_class.call(membership: loaded, api_client:, request_id: "req-1")

      expect(Event.sole.metadata).to include("role" => "local_administrator", "data_stream_codes" => ["CERTDC"])
    end

    it "writes the full trace" do
      remove

      expect(Event.sole).to have_attributes(
        event_type: "membership.deleted",
        eventable_type: "Membership",
        eventable_id: membership.id,
        metadata: {
          "api_client" => "systeme-interne",
          "api_client_uid" => api_client.uid,
          "request_id" => "req-1",
          "email" => "alice.martin@ville.fr",
          "siret" => "21750056000016",
          "insee_code" => "75056",
          "role" => "member",
          "data_stream_codes" => ["CERTDC", "DECES"]
        }
      )
    end

    it "deletes nothing when the trace fails" do
      expect(Event).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect { remove }.to raise_error(ActiveRecord::RecordInvalid)

      expect(Membership.exists?(membership.id)).to be(true)
      expect(membership.data_stream_accesses.count).to eq(2)
      expect(ProviderSession.exists?(provider_session.id)).to be(true)
      expect(Event.count).to eq(0)
    end
  end
end
