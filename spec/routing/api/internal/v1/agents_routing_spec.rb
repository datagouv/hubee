# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API internal agents routes", type: :routing do
  it "routes the operations on an agent to AgentsController" do
    expect(get: "/api/internal/v1/agents/1").to route_to("api/internal/v1/agents#show", id: "1")
    expect(post: "/api/internal/v1/agents").to route_to("api/internal/v1/agents#create")
  end

  it "answers PUT on an agent with the common 404" do
    expect(put: "/api/internal/v1/agents/1").to route_to("api/errors#not_found", path: "internal/v1/agents/1")
  end
end
