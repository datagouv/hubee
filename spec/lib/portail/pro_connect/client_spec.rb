# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::ProConnect::Client do
  let(:domain) { "https://proconnect.gouv.fr" }
  let(:rsa) { OpenSSL::PKey::RSA.generate(2048) }
  let(:jwk) { JSON::JWK.new(rsa.public_key) }

  let(:openid_config) do
    {
      issuer: domain,
      authorization_endpoint: "#{domain}/api/v2/authorize",
      token_endpoint: "#{domain}/api/v2/token",
      userinfo_endpoint: "#{domain}/api/v2/userinfo",
      end_session_endpoint: "#{domain}/api/v2/session/end",
      jwks_uri: "#{domain}/api/v2/jwks",
      response_types_supported: ["code"],
      subject_types_supported: ["public"],
      id_token_signing_alg_values_supported: ["RS256"]
    }
  end

  # Le gem ne met rien en cache par défaut ; l'initializer lui confie Rails.cache, et
  # l'environnement de test utilise :null_store, qui n'enregistre rien. Un vrai magasin,
  # neuf à chaque exemple, pour que ce qui est mis en cache le soit réellement.
  around do |example|
    originals = ENV.to_h.slice("PROCONNECT_DOMAIN", "PROCONNECT_CLIENT_ID",
      "PROCONNECT_CLIENT_SECRET", "PROCONNECT_REDIRECT_URI",
      "PROCONNECT_POST_LOGOUT_REDIRECT_URI")
    original_cache = Rails.cache
    ENV["PROCONNECT_DOMAIN"] = domain
    ENV["PROCONNECT_CLIENT_ID"] = "client-abc"
    ENV["PROCONNECT_CLIENT_SECRET"] = "s3cret"
    ENV["PROCONNECT_REDIRECT_URI"] = "https://portail.hubee.gouv.fr/connexion/proconnect/retour"
    ENV["PROCONNECT_POST_LOGOUT_REDIRECT_URI"] = "https://portail.hubee.gouv.fr/"
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    originals.each { |key, value| ENV[key] = value }
    ENV.delete_if { |key, _| key.start_with?("PROCONNECT_") && !originals.key?(key) }
    Rails.cache = original_cache
  end

  before do
    stub_request(:get, "#{domain}/.well-known/openid-configuration")
      .to_return(status: 200, body: openid_config.to_json,
        headers: {"Content-Type" => "application/json"})
    stub_request(:get, openid_config[:jwks_uri])
      .to_return(status: 200, body: {keys: [jwk]}.to_json,
        headers: {"Content-Type" => "application/json"})
  end

  def signed_user_info(overrides = {}, key: rsa, algorithm: :RS256)
    claims = {
      sub: "sub-xyz", email: "agent@example.gouv.fr", given_name: "Alex",
      usual_name: "Martin", siret: "13002526500013", idp_id: "idp-1",
      organization_label: "Mairie de Test"
    }.merge(overrides)

    JSON::JWT.new(claims).tap { |jwt| jwt.kid = jwk[:kid] }.sign(key, algorithm).to_s
  end

  def params_of(url) = Rack::Utils.parse_query(URI(url).query)

  describe ".authorization" do
    # Sans acr_values, ProConnect n'émet aucun acr et toute connexion serait refusée faute
    # de niveau d'authentification constatable.
    it "requests the amr claim as essential and the minimum authentication level" do
      params = params_of(described_class.authorization.url)

      expect(params["claims"]).to eq({id_token: {amr: {essential: true}}}.to_json)
      expect(params["acr_values"]).to eq("eidas1")
      expect(params["scope"])
        .to eq("openid given_name usual_name email siret organization_label idp_id")
      expect(params["client_id"]).to eq("client-abc")
      expect(params["response_type"]).to eq("code")
    end

    # L'élévation se demande par `claims`, pas par acr_values, qui n'annonce qu'un plancher
    # et n'oblige à rien — cf. doc ProConnect « Forcer la double authentification ».
    it "demands a second factor when stepping up" do
      params = params_of(described_class.authorization(step_up: true).url)

      expect(params["claims"]).to eq(
        {id_token: {amr: {essential: true},
                    acr: {essential: true, values: Portail::AuthenticationLevels::SECOND_FACTOR}}}.to_json
      )
      # Laisser acr_values au plancher enverrait la consigne inverse dans la même requête.
      expect(params["acr_values"]).to eq("eidas1-mfa eidas2 eidas3")
    end

    it "passes on the address and the organisation it already knows" do
      params = params_of(
        described_class.authorization(
          step_up: true, login_hint: "agent@example.gouv.fr", siret_hint: "13002526500013"
        ).url
      )

      expect(params["login_hint"]).to eq("agent@example.gouv.fr")
      expect(params["siret_hint"]).to eq("13002526500013")
    end

    it "omits the hints it was not given" do
      expect(params_of(described_class.authorization.url)).not_to have_key("login_hint")
    end

    # C'est le lien entre notre demande et la réponse : deux départs ne doivent jamais
    # partager les mêmes valeurs, sinon rejouer un callback deviendrait possible.
    it "mints a fresh state and nonce on each departure" do
      first = described_class.authorization
      second = described_class.authorization

      expect(first.state).not_to eq(second.state)
      expect(first.nonce).not_to eq(second.nonce)
      expect(params_of(first.url).values_at("state", "nonce")).to eq([first.state, first.nonce])
    end
  end

  describe ".exchange" do
    before do
      stub_request(:post, openid_config[:token_endpoint])
        .to_return(status: 200, body: {access_token: "at-1", token_type: "Bearer",
                                       id_token: "the-id-token"}.to_json,
          headers: {"Content-Type" => "application/json"})
    end

    # rack-oauth2 authentifie le client en Basic par défaut ; ProConnect attend le secret
    # dans le corps, comme le faisait omniauth-proconnect. C'est `client_auth_method:
    # :secret` qui l'obtient — le retirer casserait l'échange sans rien casser d'autre.
    it "authenticates itself with the secret in the body, not in a Basic header" do
      stub_request(:get, openid_config[:userinfo_endpoint])
        .to_return(status: 200, body: signed_user_info,
          headers: {"Content-Type" => "application/jwt"})

      described_class.exchange(code: "the-code")

      expect(WebMock).to have_requested(:post, openid_config[:token_endpoint]).with { |request|
        request.headers["Authorization"].nil? &&
          request.body.include?("client_secret=s3cret") &&
          request.body.include?("client_id=client-abc")
      }
    end

    it "returns the raw id_token and the identity claims from the userinfo" do
      stub_request(:get, openid_config[:userinfo_endpoint])
        .to_return(status: 200, body: signed_user_info,
          headers: {"Content-Type" => "application/jwt"})

      tokens = described_class.exchange(code: "the-code")

      expect(tokens.id_token).to eq("the-id-token")
      expect(tokens.info.email).to eq("agent@example.gouv.fr")
      expect(tokens.info.first_name).to eq("Alex")
      expect(tokens.info.last_name).to eq("Martin")
      expect(tokens.siret).to eq("13002526500013")
      expect(tokens.idp_id).to eq("idp-1")
      expect(tokens.organization_label).to eq("Mairie de Test")
    end

    # omniauth-proconnect décodait le userinfo en `:skip_verification`. ProConnect prend la
    # peine de le signer : on le vérifie.
    it "refuses a userinfo signed by someone else" do
      stub_request(:get, openid_config[:userinfo_endpoint])
        .to_return(status: 200, body: signed_user_info({}, key: OpenSSL::PKey::RSA.generate(2048)),
          headers: {"Content-Type" => "application/jwt"})

      expect { described_class.exchange(code: "the-code") }
        .to raise_error(described_class::Unavailable, /mal signé/)
    end

    # Le piège classique : un jeton signé avec la clé PUBLIQUE de ProConnect, que tout le
    # monde peut télécharger, présentée comme un secret partagé.
    it "refuses a userinfo signed with a non-allowed algorithm" do
      stub_request(:get, openid_config[:userinfo_endpoint])
        .to_return(status: 200, body: signed_user_info({}, key: rsa.to_s, algorithm: :HS256),
          headers: {"Content-Type" => "application/jwt"})

      expect { described_class.exchange(code: "the-code") }
        .to raise_error(described_class::Unavailable)
    end
  end

  # Une panne de ProConnect doit se présenter aux appelants sous une seule forme, pour
  # qu'ils puissent dégrader au lieu de laisser fuir une exception de transport.
  describe "when ProConnect cannot be reached or understood" do
    it "raises Unavailable when the token endpoint refuses" do
      stub_request(:post, openid_config[:token_endpoint])
        .to_return(status: 400, body: {error: "invalid_grant"}.to_json,
          headers: {"Content-Type" => "application/json"})

      expect { described_class.exchange(code: "the-code") }
        .to raise_error(described_class::Unavailable)
    end

    it "raises Unavailable when the discovery document is unreachable" do
      stub_request(:get, "#{domain}/.well-known/openid-configuration")
        .to_return(status: 502, body: "<html>Bad Gateway</html>")

      expect { described_class.authorization }.to raise_error(described_class::Unavailable)
    end
  end

  # Le gem ne met rien en cache par défaut : sa classe Cache est un passe-plat. Ces deux
  # exemples éprouvent le câblage de l'initializer — sans lui, chaque vérification de jeton
  # coûterait deux appels HTTP à ProConnect, en silence.
  describe "caching what ProConnect publishes" do
    it "reads the discovery document once, not on every departure" do
      3.times { described_class.authorization }

      expect(WebMock).to have_requested(:get, "#{domain}/.well-known/openid-configuration").once
    end

    # Le cache du JWKS est indexé par `kid` : une clé jamais vue est un défaut de cache,
    # donc une récupération immédiate. C'est ce qui fait qu'une rotation de clés chez
    # ProConnect ne coupe pas les connexions jusqu'à l'expiration du cache.
    it "goes back for a key it has never seen, so a rotation is picked up at once" do
      described_class.config.jwk(jwk[:kid])
      described_class.config.jwk(jwk[:kid])

      expect(WebMock).to have_requested(:get, openid_config[:jwks_uri]).once

      expect { described_class.config.jwk("un-kid-jamais-vu") }
        .to raise_error(JSON::JWK::Set::KidNotFound)
      expect(WebMock).to have_requested(:get, openid_config[:jwks_uri]).twice
    end
  end

  describe ".logout_url" do
    it "points at the provider's end-session endpoint and carries the id_token" do
      url = described_class.logout_url(id_token: "the-id-token")

      expect(url).to start_with("#{domain}/api/v2/session/end?")
      expect(params_of(url)).to eq(
        "id_token_hint" => "the-id-token",
        "post_logout_redirect_uri" => "https://portail.hubee.gouv.fr/"
      )
    end
  end
end
