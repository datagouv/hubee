# frozen_string_literal: true

module Portail
  module ProConnect
    # Construit l'URL end_session ProConnect (RP-initiated logout / SLO).
    # On la construit nous-mêmes plutôt que via le other_phase de la gem, pour
    # se composer avec reset_session (anti-fixation) sans dépendre des clés de
    # session internes de la gem.
    class LogoutUrlBuilder
      class << self
        def call(id_token:, discovery: Discovery.new)
          new(id_token:, discovery:).call
        end
      end

      def initialize(id_token:, discovery:)
        @id_token = id_token
        @discovery = discovery
      end

      def call
        URI(@discovery.end_session_endpoint).tap do |uri|
          uri.query = URI.encode_www_form(
            id_token_hint: @id_token,
            post_logout_redirect_uri: ENV.fetch("PROCONNECT_POST_LOGOUT_REDIRECT_URI")
          )
        end.to_s
      end
    end
  end
end
