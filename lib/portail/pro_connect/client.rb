# frozen_string_literal: true

module Portail
  module ProConnect
    # Le transport : construire la demande d'autorisation, échanger le code, lire le
    # userinfo, bâtir l'URL de déconnexion.
    #
    # Ne juge rien de ce que ProConnect répond — c'est TokenVerifier, appelé par la chaîne
    # d'interactors, qui décide si l'id_token est recevable. Ici on parle, là-bas on juge.
    class Client
      # ProConnect n'a pas répondu, ou pas de façon exploitable. Les appelants doivent
      # pouvoir dégrader plutôt que laisser fuir une exception de transport.
      class Unavailable < StandardError; end

      Authorization = Data.define(:url, :state, :nonce)
      # La seule chose utile que faisait le auth_hash d'OmniAuth : normaliser. On la garde,
      # typée — une faute de frappe lève au lieu de rendre nil en silence.
      Info = Data.define(:email, :first_name, :last_name)
      Tokens = Data.define(:id_token, :info, :siret, :idp_id, :organization_label)

      # Le plancher demandé à ProConnect, aligné sur le premier niveau que le portail
      # accepte. Voir Portail::Sessions::Create::CheckAuthenticationLevel.
      MINIMUM_AUTHENTICATION_LEVEL = "eidas1"
      SCOPES = %w[openid given_name usual_name email siret idp_id].freeze

      # ProConnect signe son userinfo en RS256. Imposé plutôt que lu dans l'en-tête du
      # jeton : sinon on accepterait `alg: HS256` signé avec sa clé publique, que tout le
      # monde peut télécharger.
      SIGNING_ALGORITHM = :RS256

      TRANSPORT_ERRORS = [
        Rack::OAuth2::Client::Error, Faraday::Error, SWD::Exception,
        OpenIDConnect::Discovery::DiscoveryFailed, JSON::ParserError
      ].freeze

      class << self
        # Appelable de partout — c'est le gain de la sortie d'OmniAuth, dont la phase
        # requête exigeait un POST du navigateur : l'élévation part directement du
        # callback, sans page intermédiaire. L'appelant range `state` et `nonce`, et les
        # représente au retour.
        def authorization(step_up: false, login_hint: nil, siret_hint: nil)
          state = SecureRandom.urlsafe_base64(32)
          nonce = SecureRandom.urlsafe_base64(32)

          url = client.authorization_uri(
            scope: SCOPES, state:, nonce:,
            claims: requested_claims(step_up),
            # Sans `acr_values`, ProConnect n'émet aucun `acr` — le demander via `claims`
            # ne suffit pas — et CheckAuthenticationLevel refuserait tout le monde faute de
            # niveau constatable. Élevé en même temps que les claims : le laisser au
            # plancher enverrait deux consignes contradictoires dans la même requête.
            acr_values: requested_acr_values(step_up),
            # L'agent vient de s'identifier : lui refaire saisir son adresse et rechoisir
            # son organisation serait gratuit. Des suggestions seulement — c'est l'`acr`
            # du jeton au retour qui fait foi.
            **{login_hint:, siret_hint:}.compact
          )

          Authorization.new(url:, state:, nonce:)
        rescue *TRANSPORT_ERRORS => e
          raise Unavailable, e.message
        end

        # Rend l'id_token brut : sa vérification appartient à TokenVerifier. Le userinfo,
        # lui, est vérifié ici — aucune autre étape ne le fera.
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

        def logout_url(id_token:, post_logout_redirect_uri:)
          query = {id_token_hint: id_token, post_logout_redirect_uri:}.compact.to_query
          "#{config.end_session_endpoint}?#{query}"
        end

        # Mis en cache par SWD.cache, câblé dans l'initializer : un appel HTTP par heure,
        # pas un par connexion. Public — TokenVerifier y prend l'émetteur et les clés.
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

        # ProConnect renvoie le userinfo en JWT signé, pas en JSON : `userinfo!` du gem
        # attend du JSON et ne convient donc pas. Et contrairement à omniauth-proconnect,
        # qui décodait en `:skip_verification`, on contrôle la signature — ProConnect prend
        # la peine de l'apposer.
        def user_info(access_token)
          jwt = access_token.get(config.userinfo_endpoint).body
          kid = JSON::JWT.decode(jwt, :skip_verification).kid

          JSON::JWT.decode(jwt, config.jwk(kid), [SIGNING_ALGORITHM]).to_h.symbolize_keys
        rescue JSON::JWT::Exception, JSON::JWK::Set::KidNotFound => e
          raise Unavailable, "userinfo illisible ou mal signé (#{e.class})"
        end

        # Le second facteur se demande par `claims`, comme le prescrit la doc ProConnect —
        # `acr_values` n'annonce qu'un plancher et n'oblige à rien. `essential: true` fait
        # renvoyer une erreur si ProConnect ne peut pas satisfaire, plutôt qu'un niveau
        # plus faible : le contrôleur la lit déjà.
        def requested_claims(step_up)
          claims = {id_token: {amr: {essential: true}}}
          claims[:id_token][:acr] = {essential: true, values: Portail::SecondFactor::LEVELS} if step_up
          claims.to_json
        end

        def requested_acr_values(step_up)
          return MINIMUM_AUTHENTICATION_LEVEL unless step_up

          Portail::SecondFactor::LEVELS.join(" ")
        end

        def client
          OpenIDConnect::Client.new(
            identifier: client_id,
            secret: ENV.fetch("PROCONNECT_CLIENT_SECRET"),
            redirect_uri: ENV.fetch("PROCONNECT_REDIRECT_URI"),
            authorization_endpoint: config.authorization_endpoint,
            token_endpoint: config.token_endpoint,
            userinfo_endpoint: config.userinfo_endpoint
          )
        end
      end
    end
  end
end
