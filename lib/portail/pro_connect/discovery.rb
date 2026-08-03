# frozen_string_literal: true

require "net/http"
require "json"
require "json/jwt"

module Portail
  module ProConnect
    # ProConnect publie, à une adresse normalisée, un annuaire JSON qui liste ses adresses
    # de service et l'endroit où trouver ses clés publiques de signature. Ce jeu de clés
    # s'appelle le JWKS. Cette classe va chercher les deux et les garde en cache.
    #
    # Pourquoi ne pas s'appuyer sur la gem, qui fait la même chose ? Parce qu'elle le fait
    # en privé, et seulement le temps où OmniAuth traite la requête d'authentification.
    # TokenVerifier et LogoutUrlBuilder s'exécutent ailleurs — dans un interactor et dans
    # un controller — et n'y ont donc pas accès.
    class Discovery
      DISCOVERY_PATH = "/.well-known/openid-configuration"
      # Le cache évite un appel HTTP à chaque vérification de jeton. Il n'est pas ce qui
      # nous fait récupérer les nouvelles clés : #jwks s'en charge, immédiatement.
      CACHE_TTL = 1.hour
      CONFIG_CACHE_KEY = "proconnect:discovery"
      JWKS_CACHE_KEY = "proconnect:jwks"
      REFRESH_LOCK_KEY = "proconnect:jwks:refresh_lock"
      REFRESH_COOLDOWN = 1.minute
      OPEN_TIMEOUT = 2
      READ_TIMEOUT = 5

      def issuer
        config.fetch("issuer")
      end

      def end_session_endpoint
        config.fetch("end_session_endpoint")
      end

      # Tout jeton signé porte dans son en-tête, en clair, l'identifiant de la clé qui a
      # servi à le signer : le `kid`. Il indique laquelle des clés publiques de ProConnect
      # utiliser pour contrôler sa signature.
      #
      # ProConnect renouvelle ses clés de temps en temps. La nouvelle est alors absente de
      # notre cache, plus aucune signature ne se vérifie, et plus personne ne peut se
      # connecter jusqu'à ce que le cache expire — une heure. On recharge donc dès qu'un
      # `kid` inconnu se présente : la coupure passe d'une heure à une seule requête.
      #
      # Le piège : ce `kid` n'est pas signé, n'importe qui peut en inventer un. Sans le
      # verrou d'une minute, il suffirait d'envoyer des jetons bidons à la chaîne pour
      # nous faire appeler ProConnect autant de fois. Pour la même raison, on ne recharge
      # jamais sur un simple échec de signature : ce serait déclenchable à volonté.
      def jwks(kid: nil)
        keys = cached_jwks
        return keys if kid.blank? || keys.any? { |key| key[:kid] == kid }
        return keys unless claim_refresh_slot!

        cached_jwks(force: true)
      end

      private

      def cached_jwks(force: false)
        Rails.cache.delete(JWKS_CACHE_KEY) if force
        raw = Rails.cache.fetch(JWKS_CACHE_KEY, expires_in: CACHE_TTL) do
          fetch_json(config.fetch("jwks_uri"))
        end
        JSON::JWK::Set.new(raw)
      end

      # `unless_exist` n'écrit que si la clé est absente, et le fait de façon atomique :
      # un seul appelant obtient `true`. Deux requêtes simultanées portant le même `kid`
      # inconnu ne déclenchent donc qu'un seul rechargement, pas deux.
      def claim_refresh_slot!
        Rails.cache.write(REFRESH_LOCK_KEY, true, expires_in: REFRESH_COOLDOWN, unless_exist: true)
      end

      def config
        @config ||= Rails.cache.fetch(CONFIG_CACHE_KEY, expires_in: CACHE_TTL) do
          fetch_json("#{ENV.fetch("PROCONNECT_DOMAIN")}#{DISCOVERY_PATH}")
        end
      end

      def fetch_json(url)
        uri = URI(url)
        # On exige HTTPS au lieu de le déduire de l'URL. Récupérées en clair, les clés
        # publiques pourraient être remplacées en chemin : la vérification de signature
        # continuerait de fonctionner, mais en validant les jetons de l'attaquant.
        raise ArgumentError, "URL ProConnect non HTTPS : #{url}" unless uri.scheme == "https"

        response = Net::HTTP.start(
          uri.host, uri.port,
          use_ssl: true,
          open_timeout: OPEN_TIMEOUT,
          read_timeout: READ_TIMEOUT
        ) { |http| http.get(uri.request_uri) }
        JSON.parse(response.body)
      end
    end
  end
end
