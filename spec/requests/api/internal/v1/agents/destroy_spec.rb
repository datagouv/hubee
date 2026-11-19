# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DELETE /api/internal/v1/agents/:id", type: :request do
  def remove(agent_id: agent.id, application: admin_portal)
    delete "/api/internal/v1/agents/#{agent_id}", headers: bearer(application)
  end

  # Le cas standard : un membre habilité sur un flux.
  def attach(agent, siret: "21750056000016", insee_code: "75056", codes: ["CERTDC"])
    membership = create(:membership, agent:, organization_link: create(:organization_link, siret:, insee_code:))
    codes.each { create(:data_stream_access, membership:, data_stream_code: it) }
    membership
  end

  # Tout ce qu'un refus ne doit pas écrire.
  def written
    [Agent.count, Membership.count, DataStreamAccess.count, ProviderSession.count, Event.count]
  end

  let(:admin_portal) { create(:oauth_application, :admin_portal, name: "admin-portal") }
  let!(:agent) { create(:agent, email: "alice.martin@ville.fr") }
  let!(:membership) { attach(agent) }
  let(:json) { JSON.parse(response.body) }

  it "removes the agent with an empty 204 and records the trace" do
    session = create(:provider_session, membership:)

    remove

    expect(response).to have_http_status(:no_content)
    expect(response.body).to be_empty
    expect(Agent.exists?(agent.id)).to be(false)
    expect(Membership.exists?(membership.id)).to be(false)
    expect(DataStreamAccess.where(membership_id: membership.id)).to be_empty
    expect(ProviderSession.exists?(session.id)).to be(false)
    expect(OrganizationLink.where(siret: "21750056000016", insee_code: "75056")).to exist
    expect(Event.sole).to have_attributes(
      event_type: "agent.deleted",
      eventable_id: agent.id,
      metadata: {
        "api_client" => "admin-portal",
        "api_client_uid" => admin_portal.uid,
        "request_id" => response.headers["X-Request-Id"],
        "email" => "alice.martin@ville.fr",
        "memberships" => [
          {"siret" => "21750056000016", "insee_code" => "75056", "role" => "member", "data_stream_codes" => ["CERTDC"]}
        ]
      }
    )
  end

  it "answers 404 when the agent is read after his deletion" do
    remove
    get "/api/internal/v1/agents/#{agent.id}", headers: bearer(admin_portal)

    expect(response).to have_http_status(:not_found)
  end

  it "lets a registration with the same address create a new agent with another id" do
    registrar = create(:oauth_application, :with_agent_registration_right)
    stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
    stub_hub_api_v2_data_stream(code: "CERTDC")
    remove

    post "/api/internal/v1/agents", headers: bearer(registrar), as: :json, params: {
      agent: {
        email: "alice.martin@ville.fr", first_name: "Alice", last_name: "Martin",
        membership: {siret: "21750056000016", insee_code: "75056", role: "member", data_stream_codes: ["CERTDC"]}
      }
    }

    expect(response).to have_http_status(:created)
    expect(json["id"]).not_to eq(agent.id)
    expect(Agent.sole.id).to eq(json["id"])
  end

  it "answers 404 for an unknown agent" do
    expect { remove(agent_id: SecureRandom.uuid) }.not_to change { written }

    expect(response).to have_http_status(:not_found)
    expect(json).to eq("error" => "not_found", "message" => "Ressource introuvable.")
  end

  it "refuses a client holding only internal:agents:update, even on an unknown agent" do
    corrector = create(:oauth_application, :with_agent_update_right)

    remove(agent_id: SecureRandom.uuid, application: corrector)

    expect(response).to have_http_status(:forbidden)
    expect(json).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
  end

  it "refuses a client holding only internal:agents:update without deleting" do
    corrector = create(:oauth_application, :with_agent_update_right)

    expect { remove(application: corrector) }.not_to change { written }

    expect(response).to have_http_status(:forbidden)
  end

  # hub-api n'a que le droit d'enregistrer : il ne supprime pas un agent.
  it "refuses a client holding only internal:agents:create, even on an unknown agent" do
    registrar = create(:oauth_application, :with_agent_registration_right)

    remove(agent_id: SecureRandom.uuid, application: registrar)

    expect(response).to have_http_status(:forbidden)
    expect(json).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
  end

  it "refuses a client holding only internal:agents:create without deleting" do
    registrar = create(:oauth_application, :with_agent_registration_right)

    expect { remove(application: registrar) }.not_to change { written }

    expect(response).to have_http_status(:forbidden)
  end

  it "accepts a client holding internal:agents:destroy alone" do
    destroyer = create(:oauth_application, :with_agent_destroy_right)

    remove(application: destroyer)

    expect(response).to have_http_status(:no_content)
  end

  it "answers 401 without a token" do
    expect { delete "/api/internal/v1/agents/#{agent.id}" }.not_to change { written }

    expect(response).to have_http_status(:unauthorized)
  end
end
