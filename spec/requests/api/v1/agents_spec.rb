# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API::V1::Agents", type: :request do
  subject(:make_request) { post "/api/v1/agents", params: payload, headers: headers, as: :json }

  let(:application) { create(:oauth_application, name: "hub-api") }
  let(:access_token) { create(:oauth_access_token, application: application) }
  let(:headers) { {"Authorization" => "Bearer #{access_token.plaintext_token}"} }
  let(:payload) do
    {agent: {
      email: "alice.martin@ville.fr", first_name: "Alice", last_name: "Martin", civility: "ms",
      memberships: [{siret: "21750056000016", insee_code: "001", role: "local_administrator",
                     job_title: "Officier d'état civil", phone_number: "+33123456789"}]
    }}
  end

  before do
    create(:organization_link, siret: "21750056000016", insee_code: "001")
  end

  describe "POST /api/v1/agents" do
    it "creates the agent and answers with the flat representation" do
      make_request

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)).to include(
        "email" => "alice.martin@ville.fr",
        "civility" => "ms",
        "first_name" => "Alice",
        "last_name" => "Martin",
        "memberships" => [{
          "siret" => "21750056000016", "insee_code" => "001",
          "role" => "local_administrator", "job_title" => "Officier d'état civil",
          "phone_number" => "+33123456789"
        }]
      )
      expect(JSON.parse(response.body)["id"]).to eq(Agent.last.id)

      body = JSON.parse(response.body)
      expect(body.keys).to contain_exactly(
        "id", "email", "civility", "first_name", "last_name", "created_at", "memberships"
      )
      expect(body["created_at"]).to be_present
    end

    it "never exposes the provider identity" do
      make_request

      expect(response.body).not_to include("provider_sub")
    end

    # Deux rattachements de SIRET différents créés en un seul appel, portés
    # tous les deux par la réponse — la vie de l'agent naît au pluriel.
    it "creates several memberships of different sirets in one call" do
      create(:organization_link, siret: "35600000000048", insee_code: "002")
      payload[:agent][:memberships] << {
        siret: "35600000000048", insee_code: "002", role: "member"
      }

      make_request

      expect(response).to have_http_status(:created)
      expect(Agent.last.memberships.count).to eq(2)
      expect(JSON.parse(response.body)["memberships"].pluck("siret"))
        .to contain_exactly("21750056000016", "35600000000048")
    end

    # Un appel rejoué aboutit au même état, sans doublon.
    it "answers a replay with a conflict and an unchanged state" do
      post "/api/v1/agents", params: payload, headers: headers, as: :json

      expect { post "/api/v1/agents", params: payload, headers: headers, as: :json }
        .not_to change(Agent, :count)
      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)).to have_key("email")
    end

    it "refuses an incomplete payload naming the faulty fields, writing nothing" do
      payload[:agent].delete(:first_name)

      expect { make_request }.not_to change(Agent, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to have_key("first_name")
    end

    it "refuses a payload without any membership, writing nothing" do
      payload[:agent][:memberships] = []

      expect { make_request }.not_to change(Agent, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to have_key("memberships")
    end

    it "refuses two memberships sharing the same siret, writing nothing" do
      payload[:agent][:memberships] << {siret: "21750056000016", insee_code: "001", role: "member"}

      expect { make_request }.not_to change(Agent, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to have_key("memberships")
    end

    it "refuses an organization the referential does not know" do
      OrganizationLink.delete_all
      allow(API::Referential::Organization).to receive(:find)
        .and_raise(API::Referential::Organization::NotFound)

      make_request

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq(
        "memberships[0].insee_code" => ["ne correspond à aucune organisation connue du référentiel"]
      )
    end

    it "reports an unavailable referential as retryable" do
      OrganizationLink.delete_all
      allow(API::Referential::Organization).to receive(:find)
        .and_raise(API::Referential::Organization::Unavailable)

      make_request

      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)).to have_key("base")
    end

    it "refuses an unauthenticated call before doing anything" do
      post "/api/v1/agents", params: payload, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(Agent.count).to eq(0)
    end

    # En test, consider_all_requests_local court-circuite exceptions_app (comme documenté
    # dans Portail::ErrorsController spec) : c'est la page de debug Rails qui répond, pas
    # notre JSON — c'est le comportement par défaut du framework pour une requête mal formée.
    it "refuses a body without the agent envelope, writing nothing" do
      expect { post "/api/v1/agents", params: {}, headers: headers, as: :json }
        .not_to change(Agent, :count)
      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include("ActionController::ParameterMissing")
    end

    it "refuses an empty agent envelope, writing nothing" do
      expect { post "/api/v1/agents", params: {agent: {}}, headers: headers, as: :json }
        .not_to change(Agent, :count)
      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include("ActionController::ParameterMissing")
    end

    # Hypothèse assumée : params.expect jette les entrées non-objet du tableau. Avec une
    # entrée valide à côté, l'appel réussit amputé — accepté, appelants internes typés.
    it "silently drops a non-object memberships entry alongside a valid one" do
      payload[:agent][:memberships] << "bogus"

      make_request

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["memberships"].size).to eq(1)
    end
  end

  describe "exception rendering" do
    # Le mode debug de l'environnement de test court-circuite l'exceptions_app : on le
    # neutralise le temps d'une requête pour exercer le vrai aiguillage de production.
    before do
      env_config = Rails.application.env_config
      allow(Rails.application).to receive(:env_config).and_return(
        env_config.merge("action_dispatch.show_detailed_exceptions" => false)
      )
    end

    it "answers an API failure with the framework JSON, never a portal page" do
      post "/api/v1/agents", params: {}, headers: headers, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq("status" => 400, "error" => "Bad Request")
    end
  end
end
