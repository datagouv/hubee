# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/internal/v1/agents/:id", type: :request do
  # Le décor par défaut est le cas standard : un membre habilité sur un flux.
  def attach(agent, role: "member", siret: "21750056000016", insee_code: "75056", codes: ["CERTDC"], **attributes)
    membership = create(:membership, agent:, role:, organization_link: create(:organization_link, siret:, insee_code:), **attributes)
    codes.each { create(:data_stream_access, membership:, data_stream_code: it) }
    membership
  end

  let(:admin_portal) { create(:oauth_application, :admin_portal) }
  let(:json) { JSON.parse(response.body) }

  # Le cas standard, rattaché avant un administrateur local sans habilitation, qui a accès à tous les flux.
  it "answers a member habilitated on a data stream, with every membership" do
    agent = create(:agent, provider_sub: nil, email: "camille.martin@ville.fr")
    member = attach(agent, job_title: "Officier d'état civil", phone_number: "+33123456789", mobile_phone_number: "+33612345678")
    administrator = attach(agent, role: "local_administrator", siret: "13002526500013", insee_code: "13055", codes: [], created_at: 1.minute.from_now)

    get "/api/internal/v1/agents/#{agent.id}", headers: bearer(admin_portal)

    expect(response).to have_http_status(:ok)
    expect(json).to eq(
      "id" => agent.id,
      "email" => "camille.martin@ville.fr",
      "first_name" => "Camille",
      "last_name" => "Martin",
      "civility" => nil,
      "has_signed_in" => false,
      "created_at" => agent.created_at.as_json,
      "memberships" => [
        {
          "id" => member.id,
          "siret" => "21750056000016",
          "insee_code" => "75056",
          "role" => "member",
          "job_title" => "Officier d'état civil",
          "phone_number" => "+33123456789",
          "mobile_phone_number" => "+33612345678",
          "data_stream_codes" => ["CERTDC"],
          "last_signed_in_at" => nil
        },
        {
          "id" => administrator.id,
          "siret" => "13002526500013",
          "insee_code" => "13055",
          "role" => "local_administrator",
          "job_title" => nil,
          "phone_number" => nil,
          "mobile_phone_number" => nil,
          "data_stream_codes" => [],
          "last_signed_in_at" => nil
        }
      ]
    )
  end

  it "tells an agent who has already signed in, without ever exposing the provider subject" do
    agent = create(:agent, provider_sub: "proconnect-sub-secret")
    signed_in_at = Time.utc(2026, 11, 10, 8, 0, 0)
    attach(agent, last_signed_in_at: signed_in_at)

    get "/api/internal/v1/agents/#{agent.id}", headers: bearer(admin_portal)

    expect(response).to have_http_status(:ok)
    expect(json).to include("has_signed_in" => true)
    expect(json.keys).not_to include("provider_sub")
    expect(Time.iso8601(json["memberships"].sole["last_signed_in_at"])).to eq(signed_in_at)
    expect(response.body).not_to include("proconnect-sub-secret")
  end

  [SecureRandom.uuid, "pas-un-uuid"].each do |id|
    it "answers 404 for an unknown agent (#{id})" do
      get "/api/internal/v1/agents/#{id}", headers: bearer(admin_portal)

      expect(response).to have_http_status(:not_found)
      expect(json).to eq("error" => "not_found", "message" => "Ressource introuvable.")
    end
  end

  it "refuses a client holding only internal:agents:create, even on an unknown agent" do
    client = create(:oauth_application, :with_agent_registration_right)

    get "/api/internal/v1/agents/#{SecureRandom.uuid}", headers: bearer(client)

    expect(response).to have_http_status(:forbidden)
    expect(json).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
  end

  it "refuses without a token" do
    get "/api/internal/v1/agents/#{create(:agent).id}"

    expect(response).to have_http_status(:unauthorized)
    expect(json).to eq("error" => "invalid_token", "message" => "Le jeton d'accès est absent, inconnu, expiré ou révoqué.")
  end
end
