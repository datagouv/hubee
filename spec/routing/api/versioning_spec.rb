require "rails_helper"

RSpec.describe "API versioning", type: :routing do
  let(:shared_by_all_versions) { ["/api/oauth/token(.:format)", "/api/ping(.:format)", "/api(/*path)"] }

  it "serves every other route under /api from /api/<namespace>/v<N>/, in API::<Namespace>::V<N>" do
    api_routes = Rails.application.routes.routes.select { it.path.spec.to_s.match?(%r{\A/api(/|\()}) }
    versioned = api_routes.reject { shared_by_all_versions.include?(it.path.spec.to_s) }

    expect(api_routes.map { it.path.spec.to_s }).to include(*shared_by_all_versions)
    expect(versioned.map { "#{it.path.spec} → #{it.defaults[:controller]}" })
      .to all(match(%r{\A/api/(?<namespace>[a-z_]+)/(?<version>v\d+)/\S* → api/\k<namespace>/\k<version>/}))
  end
end
