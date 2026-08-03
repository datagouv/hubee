# frozen_string_literal: true

require "json/jwt"

module Portail
  module ProConnect
    # À la fin d'une connexion, ProConnect renvoie un `id_token` : un jeton signé par lui,
    # qui atteste qui vient de se connecter et par quel moyen. Cette classe est le seul
    # endroit où ce jeton est réellement contrôlé.
    #
    # La gem, elle, ne le contrôle jamais : elle prend l'identité dans le `userinfo` sans
    # rien vérifier, et le `nonce` qu'elle génère au départ n'est jamais relu au retour.
    class TokenVerifier
      class InvalidToken < StandardError; end

      # Un jeton annonce lui-même, dans son en-tête, l'algorithme qui l'a signé. Se fier à
      # cette annonce est le piège classique : on peut fabriquer un jeton en le signant
      # avec la clé *publique* de ProConnect — que tout le monde peut télécharger — en la
      # présentant comme un secret partagé (algorithme HS256), ou déclarer `alg: none` et
      # ne rien signer du tout. En imposant la liste, ces deux jetons sont rejetés d'emblée.
      # Le premier cas est couvert par token_verifier_spec.rb.
      ALLOWED_ALGORITHMS = [:RS256].freeze

      class << self
        def call(id_token:, nonce:, audience:, discovery: Discovery.new)
          new(id_token:, nonce:, audience:, discovery:).call
        end
      end

      def initialize(id_token:, nonce:, audience:, discovery:)
        @id_token = id_token
        @nonce = nonce
        @audience = audience
        @discovery = discovery
      end

      def call
        claims = decode_and_verify_signature
        verify_claims!(claims)
        {sub: claims[:sub], amr: Array(claims[:amr])}
      end

      private

      attr_reader :id_token, :nonce, :audience, :discovery

      def decode_and_verify_signature
        JSON::JWT.decode(id_token, discovery.jwks(kid: token_kid), ALLOWED_ALGORITHMS)
      rescue JSON::JWT::Exception => e
        raise InvalidToken, "signature verification failed: #{e.message}"
      end

      # On lit l'en-tête sans contrôler la signature. C'est volontaire et sans risque : il
      # ne sert qu'à savoir quelle clé publique demander, et la signature est vérifiée
      # juste après, contre cette clé. Si l'identifiant de clé est inconnu, Discovery
      # recharge le jeu de clés — voir Discovery#jwks.
      def token_kid
        JSON::JWT.decode(id_token, :skip_verification).header[:kid]
      rescue JSON::JWT::Exception
        nil
      end

      # La signature prouve que ProConnect a bien émis ce jeton — rien de plus. Quatre
      # champs restent à contrôler :
      #
      #   iss   l'émetteur est bien ProConnect, et pas un autre fournisseur d'identité
      #   aud   le jeton nous était destiné, pas à un autre service branché sur ProConnect
      #   exp   il n'a pas expiré
      #   nonce il répond à la demande que nous venons d'émettre, et non à une ancienne
      #         interceptée puis rejouée
      def verify_claims!(claims)
        raise InvalidToken, "issuer mismatch" unless claims[:iss] == discovery.issuer
        raise InvalidToken, "audience mismatch" unless Array(claims[:aud]).include?(audience)
        raise InvalidToken, "token expired" if claims[:exp].to_i <= Time.current.to_i
        raise InvalidToken, "nonce mismatch" unless nonce.present? && claims[:nonce] == nonce
      end
    end
  end
end
