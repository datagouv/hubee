# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/internal/v1/agents", type: :request do
  # Le décor par défaut est le cas standard : un membre habilité sur un flux.
  def attach(agent, role: "member", siret: "21750056000016", insee_code: "75056", codes: ["CERTDC"], **attributes)
    link = OrganizationLink.find_or_create_by!(siret:, insee_code:)
    membership = create(:membership, agent:, role:, organization_link: link, **attributes)
    codes.each { create(:data_stream_access, membership:, data_stream_code: it) }
    membership
  end

  let(:admin_portal) { create(:oauth_application, :admin_portal) }
  let(:json) { JSON.parse(response.body) }

  def representation(agent, memberships)
    {
      "id" => agent.id,
      "email" => agent.email,
      "first_name" => agent.first_name,
      "last_name" => agent.last_name,
      "civility" => nil,
      "has_signed_in" => false,
      "created_at" => agent.created_at.as_json,
      "memberships" => memberships.map do |membership|
        {
          "id" => membership.id,
          "siret" => membership.organization_link.siret,
          "insee_code" => membership.organization_link.insee_code,
          "role" => membership.role,
          "job_title" => nil,
          "phone_number" => nil,
          "mobile_phone_number" => nil,
          "data_stream_codes" => membership.data_stream_codes,
          "last_signed_in_at" => nil
        }
      end
    }
  end

  # Un administrateur local sans habilitation, cas secondaire, a accès à tous les flux.
  it "lists the whole stock, ordered by email, with every membership" do
    zoe = create(:agent, provider_sub: nil, email: "zoe@ville.fr")
    alice = create(:agent, provider_sub: nil, email: "alice@ville.fr")
    zoe_member = attach(zoe)
    alice_member = attach(alice)
    alice_administrator = attach(alice, role: "local_administrator", siret: "13002526500013", insee_code: "13055", codes: [], created_at: 1.minute.from_now)

    get "/api/internal/v1/agents", headers: bearer(admin_portal)

    expect(response).to have_http_status(:ok)
    expect(json).to eq([
      representation(alice, [alice_member, alice_administrator]),
      representation(zoe, [zoe_member])
    ])
  end

  it "answers an empty list when there is no agent" do
    get "/api/internal/v1/agents", headers: bearer(admin_portal)

    expect(response).to have_http_status(:ok)
    expect(json).to eq([])
  end

  it "finds an agent by organization and returns all its memberships" do
    alice = create(:agent, provider_sub: nil, email: "alice@ville.fr")
    bob = create(:agent, email: "bob@ville.fr")
    alice_member = attach(alice)
    alice_elsewhere = attach(alice, siret: "13002526500013", insee_code: "13055", codes: ["DECES"], created_at: 1.minute.from_now)
    attach(bob, siret: "13002526500013", insee_code: "13055")

    get "/api/internal/v1/agents", params: {siret: "21750056000016"}, headers: bearer(admin_portal)

    expect(response).to have_http_status(:ok)
    expect(json).to eq([representation(alice, [alice_member, alice_elsewhere])])
  end

  it "searches the text, the role and the insee code together" do
    alice = create(:agent, provider_sub: nil, email: "alice.martin@ville.fr", first_name: "Alice", last_name: "Martin")
    # Ces deux-là répondent à la recherche texte : seuls le rôle et le code guichet les écartent.
    other_role = create(:agent, email: "alice.martin2@ville.fr", first_name: "Alice", last_name: "Martin")
    other_insee = create(:agent, email: "alice.martin3@ville.fr", first_name: "Alice", last_name: "Martin")
    membership = attach(alice, role: "local_administrator")
    attach(other_role, role: "member")
    attach(other_insee, role: "local_administrator", insee_code: "75057")

    get "/api/internal/v1/agents",
      params: {siret: "21750056000016", insee_code: "75056", role: "local_administrator", search: "alice mar"},
      headers: bearer(admin_portal)

    expect(response).to have_http_status(:ok)
    expect(json).to eq([representation(alice, [membership])])
  end

  it "does not run one query per agent" do
    agents = create_list(:agent, 4)
    agents.each { attach(it) }

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get "/api/internal/v1/agents", headers: bearer(admin_portal)
    end

    expect(response).to have_http_status(:ok)
    expect(json.size).to eq(4)
    expect(queries.grep(/FROM "(memberships|organization_links|data_stream_accesses)"/).size).to eq(3)
  end

  it "paginates with headers" do
    create(:agent, email: "a@ville.fr")
    create(:agent, email: "b@ville.fr")
    create(:agent, email: "c@ville.fr")

    get "/api/internal/v1/agents", params: {per_page: 2}, headers: bearer(admin_portal)

    expect(response).to have_http_status(:ok)
    expect(json.map { it["email"] }).to eq(%w[a@ville.fr b@ville.fr])
    expect(%w[X-Page X-Per-Page X-Total X-Total-Pages].index_with { response.headers[it] }).to eq(
      "X-Page" => "1", "X-Per-Page" => "2", "X-Total" => "3", "X-Total-Pages" => "2"
    )
  end

  it "serves the second page" do
    create(:agent, email: "a@ville.fr")
    create(:agent, email: "b@ville.fr")
    create(:agent, email: "c@ville.fr")

    get "/api/internal/v1/agents", params: {per_page: 2, page: 2}, headers: bearer(admin_portal)

    expect(json.map { it["email"] }).to eq(%w[c@ville.fr])
    expect(response.headers["X-Page"]).to eq("2")
  end

  it "refuses an insee code without a siret" do
    get "/api/internal/v1/agents", params: {insee_code: "75056"}, headers: bearer(admin_portal)

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("insee_code" => ["ne s'emploie qu'avec un SIRET"])
  end

  it "refuses a malformed siret" do
    get "/api/internal/v1/agents", params: {siret: "123"}, headers: bearer(admin_portal)

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("siret" => ["doit comporter 14 chiffres"])
  end

  it "refuses an unknown role" do
    get "/api/internal/v1/agents", params: {role: "owner"}, headers: bearer(admin_portal)

    expect(response).to have_http_status(:unprocessable_content)
    expect(json.keys).to eq(["role"])
  end

  # Une recherche qui n'est pas une chaîne, écartée, rendrait tout le stock.
  it "refuses a criterion that is not a string" do
    create(:agent)
    seen = {}

    ["search[]=alice", "siret[a]=21750056000016", "role[]=member", "siret=21750056000016&insee_code[]=75056"].each do |query|
      get "/api/internal/v1/agents?#{query}", headers: bearer(admin_portal)
      seen[query] = [response.status, JSON.parse(response.body)]
    end

    expect(seen).to eq(
      "search[]=alice" => [422, {"search" => ["doit être une chaîne, pas une liste ni un objet"]}],
      "siret[a]=21750056000016" => [422, {"siret" => ["doit être une chaîne, pas une liste ni un objet"]}],
      "role[]=member" => [422, {"role" => ["doit être une chaîne, pas une liste ni un objet"]}],
      "siret=21750056000016&insee_code[]=75056" => [422, {"insee_code" => ["doit être une chaîne, pas une liste ni un objet"]}]
    )
  end

  it "refuses a search longer than 255 characters" do
    get "/api/internal/v1/agents", params: {search: "a" * 256}, headers: bearer(admin_portal)

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("search" => ["est trop long (pas plus de 255 caractères)"])
  end

  # Les critères se lisent dans la chaîne de requête seule : un corps de GET n'est ni lu ni refusé.
  it "ignores the criteria of a JSON body" do
    create(:agent, email: "alice@ville.fr")
    create(:agent, email: "zoe@ville.fr")

    get "/api/internal/v1/agents?search=zoe", headers: {"CONTENT_TYPE" => "application/json", **bearer(admin_portal)},
      env: {"RAW_POST_DATA" => {search: "alice", per_page: 0, role: ["member"]}.to_json}

    expect(response).to have_http_status(:ok)
    expect(json.map { it["email"] }).to eq(%w[zoe@ville.fr])
    expect(response.headers["X-Per-Page"]).to eq("50")
  end

  it "ignores an unknown parameter" do
    create(:agent)

    get "/api/internal/v1/agents", params: {unknown: "x"}, headers: bearer(admin_portal)

    expect(response).to have_http_status(:ok)
    expect(json.size).to eq(1)
  end

  # Les liens de l'en-tête Link reprennent les critères validés et la taille de page.
  it "links the next page with the criteria" do
    create(:agent, email: "alice@ville.fr")
    create(:agent, email: "alain@ville.fr")

    get "/api/internal/v1/agents", params: {search: "al", per_page: 1}, headers: bearer(admin_portal)

    expect(response).to have_http_status(:ok)
    expect(json.map { it["email"] }).to eq(%w[alain@ville.fr])
    expect(response.headers["Link"]).to include("<http://www.example.com/api/internal/v1/agents?search=al&per_page=1&page=2>; rel=\"next\"")
  end

  it "answers an empty list for a page beyond the last one" do
    create(:agent)

    get "/api/internal/v1/agents", params: {page: 99}, headers: bearer(admin_portal)

    expect(response).to have_http_status(:ok)
    expect(json).to eq([])
    expect(%w[X-Page X-Per-Page X-Total X-Total-Pages].index_with { response.headers[it] }).to eq(
      "X-Page" => "99", "X-Per-Page" => "50", "X-Total" => "1", "X-Total-Pages" => "1"
    )
  end

  # Une pagination hors bornes est refusée avec son motif, comme un autre critère, et jamais en 500.
  it "refuses a pagination out of bounds" do
    create(:agent)
    seen = {}

    ["page=abc", "page=0", "page=-5", "page=1.5", "page=1001", "page=1#{"0" * 30}", "page[]=2",
      "per_page=0", "per_page=-5", "per_page=101", "per_page[a]=2"].each do |query|
      get "/api/internal/v1/agents?#{query}", headers: bearer(admin_portal)
      seen[query] = [response.status, JSON.parse(response.body)]
    end

    expect(seen).to eq(
      "page=abc" => [422, {"page" => ["n'est pas un nombre"]}],
      "page=0" => [422, {"page" => ["doit être supérieur ou égal à 1"]}],
      "page=-5" => [422, {"page" => ["doit être supérieur ou égal à 1"]}],
      "page=1.5" => [422, {"page" => ["doit être un nombre entier"]}],
      "page=1001" => [422, {"page" => ["doit être inférieur ou égal à 1000"]}],
      "page=1#{"0" * 30}" => [422, {"page" => ["doit être inférieur ou égal à 1000"]}],
      "page[]=2" => [422, {"page" => ["n'est pas un nombre"]}],
      "per_page=0" => [422, {"per_page" => ["doit être supérieur ou égal à 1"]}],
      "per_page=-5" => [422, {"per_page" => ["doit être supérieur ou égal à 1"]}],
      "per_page=101" => [422, {"per_page" => ["doit être inférieur ou égal à 100"]}],
      "per_page[a]=2" => [422, {"per_page" => ["n'est pas un nombre"]}]
    )
  end

  it "refuses a client holding only internal:agents:create" do
    client = create(:oauth_application, :with_agent_registration_right)

    get "/api/internal/v1/agents", params: {insee_code: "75056"}, headers: bearer(client)

    expect(response).to have_http_status(:forbidden)
    expect(json).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
  end

  it "refuses without a token" do
    get "/api/internal/v1/agents"

    expect(response).to have_http_status(:unauthorized)
    expect(json).to eq("error" => "invalid_token", "message" => "Le jeton d'accès est absent, inconnu, expiré ou révoqué.")
  end
end
