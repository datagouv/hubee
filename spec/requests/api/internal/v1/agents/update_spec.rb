# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PATCH /api/internal/v1/agents/:id", type: :request do
  def correct(agent_id, body, application: admin_portal)
    patch "/api/internal/v1/agents/#{agent_id}", params: body, headers: bearer(application), as: :json
  end

  # Le cas standard : un membre habilité sur un flux.
  def attach(agent, siret: "21750056000016", insee_code: "75056", codes: ["CERTDC"])
    membership = create(:membership, agent:, organization_link: create(:organization_link, siret:, insee_code:))
    codes.each { create(:data_stream_access, membership:, data_stream_code: it) }
    membership
  end

  # Tout ce qu'un refus ne doit pas écrire.
  def written
    [agent.reload.attributes, Event.count]
  end

  let(:admin_portal) { create(:oauth_application, :admin_portal, name: "admin-portal") }
  let!(:agent) { create(:agent, email: "alice.martin@ville.fr", provider_sub: "sub-alice") }
  let!(:membership) { attach(agent) }
  let(:json) { JSON.parse(response.body) }

  # Les sessions ouvertes ne sont pas l'affaire de l'API : le portail ferme à la requête suivante celle
  # dont l'adresse n'est plus celle de l'agent (cf. agents_management_access_spec).
  it "corrects the email and answers the registered state" do
    correct(agent.id, {agent: {email: "Alice.Dupont@Ville.fr", civility: "ms"}})

    expect(response).to have_http_status(:ok)
    expect(json).to eq(
      "id" => agent.id,
      "email" => "alice.dupont@ville.fr",
      "first_name" => "Camille",
      "last_name" => "Martin",
      "civility" => "ms",
      "has_signed_in" => true,
      "created_at" => agent.created_at.as_json,
      "memberships" => [
        {
          "id" => membership.id,
          "siret" => "21750056000016",
          "insee_code" => "75056",
          "role" => "member",
          "job_title" => nil,
          "phone_number" => nil,
          "mobile_phone_number" => nil,
          "data_stream_codes" => ["CERTDC"],
          "last_signed_in_at" => nil
        }
      ]
    )
    expect(Event.sole).to have_attributes(
      event_type: "agent.updated",
      eventable: agent,
      metadata: {
        "api_client" => "admin-portal",
        "api_client_uid" => admin_portal.uid,
        "request_id" => response.headers["X-Request-Id"],
        "email" => "alice.dupont@ville.fr",
        "changes" => {
          "email" => ["alice.martin@ville.fr", "alice.dupont@ville.fr"],
          "civility" => [nil, "ms"]
        }
      }
    )
  end

  it "erases the civility with a null" do
    agent.update!(civility: "ms")

    correct(agent.id, {agent: {civility: nil}})

    expect(response).to have_http_status(:ok)
    expect(json).to include("civility" => nil, "email" => "alice.martin@ville.fr")
    expect(Event.sole.metadata).to include("changes" => {"civility" => ["ms", nil]})
  end

  # admin-portal journalise qui a agi sous l'identifiant qu'il envoie : la trace doit porter le même.
  it "traces the request id sent by the client, stripped of the characters it may not hold" do
    patch "/api/internal/v1/agents/#{agent.id}", params: {agent: {civility: "ms"}},
      headers: {"X-Request-Id" => "admin-portal_42@op:é", **bearer(admin_portal)}, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.headers["X-Request-Id"]).to eq("admin-portal_42@op")
    expect(Event.sole.metadata["request_id"]).to eq("admin-portal_42@op")
  end

  it "ignores first_name and last_name" do
    correct(agent.id, {agent: {first_name: "Zoé", last_name: "Durand", civility: "mr"}})

    expect(response).to have_http_status(:ok)
    expect(agent.reload).to have_attributes(first_name: "Camille", last_name: "Martin", civility: "mr")
    expect(Event.sole.metadata).to include("changes" => {"civility" => [nil, "mr"]})
  end

  it "writes nothing for the same email in another case" do
    expect { correct(agent.id, {agent: {email: "ALICE.Martin@ville.fr"}}) }.not_to change { written }

    expect(response).to have_http_status(:ok)
    expect(json).to include("email" => "alice.martin@ville.fr")
  end

  [{}, {first_name: "Zoé"}].each do |identity|
    it "answers the current state without writing for an envelope holding nothing to correct (#{identity})" do
      expect { correct(agent.id, {agent: identity}) }.not_to change { written }

      expect(response).to have_http_status(:ok)
      expect(json).to include("id" => agent.id, "email" => "alice.martin@ville.fr", "civility" => nil)
    end
  end

  it "refuses a malformed email and an unknown civility together" do
    expect { correct(agent.id, {agent: {email: "pas-une-adresse", civility: "x"}}) }.not_to change { written }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("email" => ["n'est pas valide"], "civility" => ["n'est pas inclus(e) dans la liste"])
  end

  [["alice.dupont@ville.fr"], {}, 5, true].each do |email|
    it "refuses a non-scalar email instead of dropping it (#{email.inspect})" do
      expect { correct(agent.id, {agent: {email:}}) }.not_to change { written }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.keys).to eq(["email"])
    end
  end

  [["mr"], {}].each do |civility|
    it "refuses a non-scalar civility instead of dropping it (#{civility.inspect})" do
      expect { correct(agent.id, {agent: {civility:}}) }.not_to change { written }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq("civility" => ["n'est pas inclus(e) dans la liste"])
    end
  end

  it "refuses an email longer than 254 characters" do
    email = "#{"a" * 65}@#{"b" * 63}.#{"c" * 63}.#{"d" * 58}.fr"

    expect { correct(agent.id, {agent: {email:}}) }.not_to change { written }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("email" => ["est trop long (pas plus de 254 caractères)"])
  end

  it "refuses a blank email" do
    expect { correct(agent.id, {agent: {email: ""}}) }.not_to change { written }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("email" => ["doit être rempli(e)"])
  end

  [nil, "alice", ["alice"]].each do |envelope|
    it "refuses an agent that is not an object (#{envelope.inspect})" do
      expect { correct(agent.id, {agent: envelope}) }.not_to change { written }

      expect(response).to have_http_status(:bad_request)
      expect(json).to include("error" => "missing_agent")
    end
  end

  it "refuses a request without the agent envelope" do
    expect { correct(agent.id, {email: "alice.dupont@ville.fr"}) }.not_to change { written }

    expect(response).to have_http_status(:bad_request)
    expect(json).to eq("error" => "missing_agent", "message" => "La demande doit porter l'agent sous la clé « agent ».")
  end

  [SecureRandom.uuid, "pas-un-uuid"].each do |id|
    it "answers 404 for an unknown agent (#{id})" do
      correct(id, {agent: {civility: "ms"}})

      expect(response).to have_http_status(:not_found)
      expect(json).to eq("error" => "not_found", "message" => "Ressource introuvable.")
    end
  end

  it "refuses a client holding only internal:agents:read, even on an unknown agent" do
    reader = create(:oauth_application, :with_agent_read_right)

    correct(SecureRandom.uuid, {agent: {civility: "ms"}}, application: reader)

    expect(response).to have_http_status(:forbidden)
    expect(json).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
  end

  it "refuses a client holding only internal:agents:read without writing" do
    reader = create(:oauth_application, :with_agent_read_right)

    expect { correct(agent.id, {agent: {civility: "ms"}}, application: reader) }.not_to change { written }

    expect(response).to have_http_status(:forbidden)
  end

  # hub-api n'a que le droit d'enregistrer : il ne corrige pas un agent.
  it "refuses a client holding only internal:agents:create, even on an unknown agent" do
    registrar = create(:oauth_application, :with_agent_registration_right)

    correct(SecureRandom.uuid, {agent: {civility: "ms"}}, application: registrar)

    expect(response).to have_http_status(:forbidden)
    expect(json).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
  end

  it "refuses a client holding only internal:agents:create without writing" do
    registrar = create(:oauth_application, :with_agent_registration_right)

    expect { correct(agent.id, {agent: {email: "alice.dupont@ville.fr", civility: "ms"}}, application: registrar) }.not_to change { written }

    expect(response).to have_http_status(:forbidden)
  end

  # L'autorisation passe avant la lecture du corps, qui passe avant la recherche de l'agent.
  context "with an unreadable body", :production_exceptions do
    def correct_unreadable(application)
      patch "/api/internal/v1/agents/#{SecureRandom.uuid}", params: "{pas du json", headers: {"CONTENT_TYPE" => "application/json", **bearer(application)}
    end

    it "answers 403 to a client without the right, even on an unknown agent" do
      correct_unreadable(create(:oauth_application))

      expect(response).to have_http_status(:forbidden)
      expect(json).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
    end

    it "answers 400 to a client with the right, before looking for the unknown agent" do
      correct_unreadable(admin_portal)

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq("error" => "bad_request", "message" => "La requête est mal formée.")
    end
  end

  it "refuses without a token" do
    patch "/api/internal/v1/agents/#{agent.id}", params: {agent: {civility: "ms"}}, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(json).to eq("error" => "invalid_token", "message" => "Le jeton d'accès est absent, inconnu, expiré ou révoqué.")
  end
end
