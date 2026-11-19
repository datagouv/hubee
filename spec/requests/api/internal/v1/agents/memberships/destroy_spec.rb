# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DELETE /api/internal/v1/agents/:agent_id/memberships/:id", type: :request do
  def remove(agent_id: agent.id, membership_id: membership.id, application: admin_portal, actor: declared_actor)
    delete "/api/internal/v1/agents/#{agent_id}/memberships/#{membership_id}", headers: {**bearer(application), **actor}
  end

  # Le cas standard : un membre habilité sur un flux.
  def attach(agent, siret: "21750056000016", insee_code: "75056", codes: ["CERTDC"])
    membership = create(:membership, agent:, organization_link: create(:organization_link, siret:, insee_code:))
    codes.each { create(:data_stream_access, membership:, data_stream_code: it) }
    membership
  end

  # Tout ce qu'un refus ne doit pas écrire.
  def written
    [Membership.count, DataStreamAccess.count, ProviderSession.count, Event.count]
  end

  let(:admin_portal) { create(:oauth_application, :admin_portal, name: "admin-portal") }
  let!(:agent) { create(:agent, email: "alice.martin@ville.fr") }
  let!(:membership) { attach(agent) }
  let(:json) { JSON.parse(response.body) }

  it "removes the membership with an empty 204 and records the trace" do
    remove

    expect(response).to have_http_status(:no_content)
    expect(response.body).to be_empty
    expect(Membership.exists?(membership.id)).to be(false)
    expect(DataStreamAccess.where(membership_id: membership.id)).to be_empty
    expect(Event.sole).to have_attributes(
      event_type: "membership.deleted",
      eventable_id: membership.id,
      metadata: {
        "api_client" => "admin-portal",
        "api_client_uid" => admin_portal.uid,
        "request_id" => response.headers["X-Request-Id"],
        "declared_actor" => "admin-national-42",
        "email" => "alice.martin@ville.fr",
        "siret" => "21750056000016",
        "insee_code" => "75056",
        "role" => "member",
        "data_stream_codes" => ["CERTDC"]
      }
    )
  end

  it "removes the last membership and leaves the agent without access" do
    remove

    expect(response).to have_http_status(:no_content)
    expect(agent.reload.memberships).to be_empty
  end

  it "keeps the other membership of the agent, its habilitations and its sessions" do
    other = attach(agent, siret: "13002526500013", insee_code: "75101", codes: ["DECES"])
    kept_session = create(:provider_session, membership: other)
    removed_session = create(:provider_session, membership:)

    remove

    expect(response).to have_http_status(:no_content)
    expect(ProviderSession.exists?(removed_session.id)).to be(false)
    expect(agent.reload.memberships).to eq([other])
    expect(other.data_stream_accesses.pluck(:data_stream_code)).to eq(["DECES"])
    expect(ProviderSession.exists?(kept_session.id)).to be(true)
  end

  it "answers 404 for the membership of another agent" do
    other = attach(create(:agent), siret: "13002526500013")

    expect { remove(membership_id: other.id) }.not_to change { written }

    expect(response).to have_http_status(:not_found)
    expect(json).to eq("error" => "not_found", "message" => "Ressource introuvable.")
  end

  [["agent", {agent_id: "inconnu"}], ["membership", {membership_id: "inconnu"}]].each do |name, ids|
    it "answers 404 for an unknown #{name}" do
      expect { remove(**ids) }.not_to change { written }

      expect(response).to have_http_status(:not_found)
    end
  end

  # hub-api n'a que le droit d'enregistrer : il ne retire pas un rattachement.
  it "refuses a client holding only internal:agents:create, even on an unknown membership" do
    registrar = create(:oauth_application, :with_agent_registration_right)

    remove(agent_id: SecureRandom.uuid, membership_id: SecureRandom.uuid, application: registrar)

    expect(response).to have_http_status(:forbidden)
    expect(json).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
  end

  it "refuses a client holding only internal:agents:create without deleting" do
    registrar = create(:oauth_application, :with_agent_registration_right)

    expect { remove(application: registrar) }.not_to change { written }

    expect(response).to have_http_status(:forbidden)
  end

  it "refuses a client holding only internal:agents:read, even on an unknown membership" do
    reader = create(:oauth_application, :with_agent_read_right)

    remove(agent_id: SecureRandom.uuid, membership_id: SecureRandom.uuid, application: reader)

    expect(response).to have_http_status(:forbidden)
    expect(json).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
  end

  it "refuses a client holding only internal:agents:read without deleting" do
    reader = create(:oauth_application, :with_agent_read_right)

    expect { remove(application: reader) }.not_to change { written }

    expect(response).to have_http_status(:forbidden)
  end

  it_behaves_like "a write requiring the declared actor" do
    def write_as(actor) = remove(actor:)
  end

  it "answers 403 to a client without the right before asking for the declared actor" do
    reader = create(:oauth_application, :with_agent_read_right)

    remove(application: reader, actor: {})

    expect(response).to have_http_status(:forbidden)
  end

  it "asks for the declared actor before looking for the membership" do
    remove(membership_id: SecureRandom.uuid, actor: {})

    expect(response).to have_http_status(:bad_request)
    expect(json).to include("error" => "missing_actor")
  end

  it "answers 401 without a token" do
    expect { delete "/api/internal/v1/agents/#{agent.id}/memberships/#{membership.id}" }.not_to change { written }

    expect(response).to have_http_status(:unauthorized)
  end
end
