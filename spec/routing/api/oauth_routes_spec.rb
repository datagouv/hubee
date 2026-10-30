require "rails_helper"

RSpec.describe "API OAuth routes", type: :routing do
  # La propriété testée est l'absence de surface : seule la délivrance de token
  # est exposée, pas les autres endpoints dessinés par défaut par Doorkeeper.
  it "routes only the token delivery endpoint" do
    expect(post: "/api/oauth/token").to route_to("doorkeeper/tokens#create")
    expect(post: "/api/oauth/revoke").to route_to("api/errors#not_found", path: "oauth/revoke")
    expect(post: "/api/oauth/introspect").to route_to("api/errors#not_found", path: "oauth/introspect")
    expect(get: "/api/oauth/token/info").to route_to("api/errors#not_found", path: "oauth/token/info")
  end
end
