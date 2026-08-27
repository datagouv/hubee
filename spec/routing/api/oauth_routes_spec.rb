require "rails_helper"

RSpec.describe "API OAuth routes", type: :routing do
  # La propriété testée est l'absence de surface : seule la délivrance de token
  # est exposée, pas les autres endpoints dessinés par défaut par Doorkeeper.
  it "routes only the token delivery endpoint" do
    expect(post: "/api/oauth/token").to route_to("doorkeeper/tokens#create")
    expect(post: "/api/oauth/revoke").not_to be_routable
    expect(post: "/api/oauth/introspect").not_to be_routable
    expect(get: "/api/oauth/token/info").not_to be_routable
  end
end
