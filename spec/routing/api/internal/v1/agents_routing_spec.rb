# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API internal agents routes", type: :routing do
  it "routes the operations on an agent to AgentsController" do
    expect(get: "/api/internal/v1/agents").to route_to("api/internal/v1/agents#index")
    expect(get: "/api/internal/v1/agents/1").to route_to("api/internal/v1/agents#show", id: "1")
    expect(post: "/api/internal/v1/agents").to route_to("api/internal/v1/agents#create")
    expect(patch: "/api/internal/v1/agents/1").to route_to("api/internal/v1/agents#update", id: "1")
  end

  # `resources` routerait aussi PUT vers update : le contrat n'offre que PATCH.
  it "answers PUT on an agent with the common 404" do
    expect(put: "/api/internal/v1/agents/1").to route_to("api/errors#not_found", path: "internal/v1/agents/1")
  end

  it "routes the operations on a membership to Agents::MembershipsController" do
    expect(patch: "/api/internal/v1/agents/1/memberships/2")
      .to route_to("api/internal/v1/agents/memberships#update", agent_id: "1", id: "2")
    expect(delete: "/api/internal/v1/agents/1/memberships/2")
      .to route_to("api/internal/v1/agents/memberships#destroy", agent_id: "1", id: "2")
  end

  # Hors du bloc `resources`, la route PATCH d'un agent prendrait sinon le nom du namespace.
  it "names no route after the bare namespace" do
    expect(Rails.application.routes.named_routes.key?(:api_internal_v1)).to be(false)
  end

  it "answers PUT on a membership with the common 404" do
    expect(put: "/api/internal/v1/agents/1/memberships/2")
      .to route_to("api/errors#not_found", path: "internal/v1/agents/1/memberships/2")
  end
end
