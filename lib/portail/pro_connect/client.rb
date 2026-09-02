# frozen_string_literal: true

module Portail
  module ProConnect
    # Dialogue OIDC avec ProConnect : autorisation, échange du code, userinfo, déconnexion.
    # Ne juge pas ce que ProConnect répond — la vérification de l'id_token appartient à
    # TokenVerifier, appelé par la chaîne d'interactors.
    class Client
      # ProConnect n'a pas répondu, ou pas de façon exploitable : les appelants dégradent.
      class Unavailable < StandardError; end

      Authorization = Data.define(:url, :state, :nonce)
      # Typés : une clé absente lève, là où un Hash rendrait nil en silence.
      Info = Data.define(:email, :first_name, :last_name)
      Tokens = Data.define(:id_token, :info, :siret, :idp_id, :organization_label)

      # `organization_label` nomme l'organisation sur la page de refus. `idp_id` trace le
      # fournisseur d'identité et demande une habilitation ProConnect — sans elle,
      # l'autorisation échoue entièrement ; retirer le mot suffit à revenir en arrière.
      SCOPES = %w[openid given_name usual_name email siret organization_label idp_id].freeze

      # Imposé, jamais lu dans le jeton : un HS256 signé avec la clé publique passerait sinon.
      SIGNING_ALGORITHM = :RS256

      TRANSPORT_ERRORS = [
        Rack::OAuth2::Client::Error, Faraday::Error, SWD::Exception,
        OpenIDConnect::Discovery::DiscoveryFailed, JSON::ParserError
      ].freeze

      class << self
        # Construit l'URL de départ ; l'appelant range `state` et `nonce` en session et
        # les représente au retour.
        def authorization(step_up: false, login_hint: nil, siret_hint: nil)
          state = SecureRandom.urlsafe_base64(32)
          nonce = SecureRandom.urlsafe_base64(32)

          url = client.authorization_uri(
            scope: SCOPES, state:, nonce:,
            claims: requested_claims(step_up),
            # Les deux doivent dire la même chose : sans acr_values, ProConnect n'émet
            # aucun acr, et un plancher contredirait l'exigence MFA des claims.
            acr_values: requested_acr_values(step_up),
            # Suggestions seulement : c'est l'acr du jeton au retour qui fait foi.
            **{login_hint:, siret_hint:}.compact
          )

          Authorization.new(url:, state:, nonce:)
        rescue *TRANSPORT_ERRORS => e
          raise Unavailable, e.message
        end

        # Échange le code contre les jetons. L'id_token part brut vers TokenVerifier ;
        # le userinfo est vérifié ici, aucune autre étape ne le fera.
        def exchange(code:)
          tokens = client.tap { |c| c.authorization_code = code }
            .access_token!(client_auth_method: :secret)
          claims = user_info(tokens)

          Tokens.new(
            id_token: tokens.id_token,
            info: Info.new(email: claims[:email], first_name: claims[:given_name],
              last_name: claims[:usual_name]),
            siret: claims[:siret], idp_id: claims[:idp_id],
            organization_label: claims[:organization_label]
          )
        rescue *TRANSPORT_ERRORS => e
          raise Unavailable, e.message
        end

        def logout_url(id_token:,
          post_logout_redirect_uri: ENV.fetch("PROCONNECT_POST_LOGOUT_REDIRECT_URI"))
          query = {id_token_hint: id_token, post_logout_redirect_uri:}.compact.to_query
          "#{config.end_session_endpoint}?#{query}"
        end

        # Annuaire ProConnect (endpoints, clés publiques), en cache une heure — cf.
        # config/initializers/pro_connect.rb.
        def config
          OpenIDConnect::Discovery::Provider::Config.discover!(
            ENV.fetch("PROCONNECT_DOMAIN"), expires_in: DISCOVERY_TTL
          )
        rescue *TRANSPORT_ERRORS => e
          raise Unavailable, e.message
        end

        def client_id = ENV.fetch("PROCONNECT_CLIENT_ID")

        private

        DISCOVERY_TTL = 1.hour
        private_constant :DISCOVERY_TTL

        # ProConnect renvoie un JWT signé là où `userinfo!` du gem attend du JSON : on le
        # décode nous-mêmes, signature vérifiée.
        def user_info(access_token)
          jwt = access_token.get(config.userinfo_endpoint).body
          kid = JSON::JWT.decode(jwt, :skip_verification).kid

          JSON::JWT.decode(jwt, config.jwk(kid), [SIGNING_ALGORITHM]).to_h.symbolize_keys
        rescue JSON::JWT::Exception, JSON::JWK::Set::KidNotFound => e
          raise Unavailable, "userinfo illisible ou mal signé (#{e.class})"
        end

        # L'exigence MFA se demande par `claims`, `essential: true` : ProConnect répond
        # par une erreur plutôt que par un niveau plus faible.
        def requested_claims(step_up)
          id_token = {amr: {essential: true}}
          id_token[:acr] = {essential: true, values: demanded(step_up)} if step_up

          {id_token:}.to_json
        end

        def requested_acr_values(step_up) = demanded(step_up).join(" ")

        def demanded(step_up) = Portail::Access::AuthenticationLevels.demanded(step_up:)

        def client
          discovered = config

          OpenIDConnect::Client.new(
            identifier: client_id,
            secret: ENV.fetch("PROCONNECT_CLIENT_SECRET"),
            redirect_uri: ENV.fetch("PROCONNECT_REDIRECT_URI"),
            authorization_endpoint: discovered.authorization_endpoint,
            token_endpoint: discovered.token_endpoint,
            userinfo_endpoint: discovered.userinfo_endpoint
          )
        end
      end
    end
  end
end
