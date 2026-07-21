# frozen_string_literal: true

require "rails_helper"
require "omni_auth/strategies/proconnect_hardened"

RSpec.describe OmniAuth::Strategies::ProconnectHardened do
  subject(:strategy) do
    described_class.new(
      ->(_env) { [200, {}, ["ok"]] },
      client_id: "client-abc",
      redirect_uri: "https://portail.hubee.gouv.fr/auth/proconnect/callback",
      scope: "openid given_name usual_name email"
    )
  end

  describe "#authorization_uri" do
    it "requests the amr claim as essential in the id_token" do
      expect(strategy).to receive(:discovered_configuration)
        .and_return("authorization_endpoint" => "https://proconnect.gouv.fr/api/v2/authorize")
      expect(strategy).to receive(:store_new_state!).and_return("state-1")
      expect(strategy).to receive(:store_new_nonce!).and_return("nonce-1")

      uri = strategy.send(:authorization_uri)
      params = Rack::Utils.parse_query(URI(uri).query)

      expect(params["claims"]).to eq({id_token: {amr: {essential: true}}}.to_json)
      expect(params["scope"]).to eq("openid given_name usual_name email")
    end
  end

  describe "#credentials" do
    it "reads the id_token from the gem's session key" do
      expect(strategy).to receive(:session).and_return({"omniauth.pc.id_token" => "the-id-token"})

      expect(strategy.credentials[:id_token]).to eq("the-id-token")
    end
  end

  describe "#extra" do
    it "reads the nonce from the gem's session key" do
      expect(strategy).to receive(:session).and_return({"omniauth.nonce" => "the-nonce"})

      expect(strategy.extra[:nonce]).to eq("the-nonce")
    end
  end
end
