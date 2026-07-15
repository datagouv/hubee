# frozen_string_literal: true

require "rails_helper"

# La CSP minimale (defense-in-depth) est active dans tous les environnements via
# config/initializers/content_security_policy.rb. On vérifie ici le contrat de la
# politique sur une réponse HTML rendue (page d'accueil du portail).
RSpec.describe "Content Security Policy", type: :request do
  subject(:csp) { response.headers["Content-Security-Policy"] }

  before { get "/" }

  it "sets an enforcing Content-Security-Policy header" do
    expect(response).to have_http_status(:success)
    expect(csp).to be_present
  end

  it "locks the base policy to self and forbids plugins" do
    expect(csp).to include("default-src 'self'")
    expect(csp).to include("object-src 'none'")
    expect(csp).to include("connect-src 'self'")
    expect(csp).to include("img-src 'self' data:")
    expect(csp).to include("font-src 'self' data:")
  end

  it "allows scripts only from self with a per-request nonce (importmap)" do
    expect(csp).to match(/script-src 'self' 'nonce-[^']+'/)
  end

  it "allows inline styles required by the DSFR runtime (without a nonce)" do
    expect(csp).to include("style-src 'self' 'unsafe-inline'")
  end
end
