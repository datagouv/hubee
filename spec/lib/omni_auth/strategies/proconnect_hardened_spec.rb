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
    # Sans acr_values, ProConnect n'émet aucun acr et toute connexion serait refusée
    # faute de niveau d'authentification constatable.
    it "requests the amr claim as essential and the minimum authentication level" do
      expect(strategy).to receive(:discovered_configuration)
        .and_return("authorization_endpoint" => "https://proconnect.gouv.fr/api/v2/authorize")
      expect(strategy).to receive(:store_new_state!).and_return("state-1")
      expect(strategy).to receive(:store_new_nonce!).and_return("nonce-1")

      uri = strategy.send(:authorization_uri)
      params = Rack::Utils.parse_query(URI(uri).query)

      expect(params["claims"]).to eq({id_token: {amr: {essential: true}}}.to_json)
      expect(params["acr_values"]).to eq("eidas1")
      expect(params["scope"]).to eq("openid given_name usual_name email")
    end
  end

  # ProConnect renvoie ses refus en paramètre. La gem ne les lit pas : elle enchaîne
  # l'échange du code, qui échoue plus loin sous un motif trompeur — une erreur de
  # décodage JWT là où il faudrait lire « accès refusé ».
  describe "#callback_phase" do
    it "fails with the reason ProConnect gave instead of exchanging the code" do
      expect(strategy).to receive(:request).at_least(:once)
        .and_return(instance_double(Rack::Request, params: {"error" => "access_denied"}))
      expect(strategy).to receive(:fail!).with("access_denied")

      strategy.callback_phase
    end

    it "hands over to the gem when ProConnect returned no error" do
      expect(strategy).to receive(:request).at_least(:once)
        .and_return(instance_double(Rack::Request, params: {"code" => "abc", "state" => "s"}))
      expect(strategy).not_to receive(:fail!)
      # Première chose que fait la gem : on s'arrête là, le reste appellerait ProConnect.
      expect(strategy).to receive(:verify_state!).and_raise(ArgumentError, "délégué")

      expect { strategy.callback_phase }.to raise_error(ArgumentError, "délégué")
    end
  end

  # Ces specs verrouillent NOTRE côté du contrat : que les blocs lisent bien les clés
  # de session attendues. Ils n'exercent pas la gem qui les écrit (store_tokens! /
  # store_new_nonce!) — un renommage côté gem ne serait donc pas capté ici ; ce résiduel
  # se valide contre l'intégration ProConnect réelle (cf. spec §12).
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
