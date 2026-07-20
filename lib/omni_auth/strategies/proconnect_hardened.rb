# frozen_string_literal: true

require "omniauth/proconnect"

module OmniAuth
  module Strategies
    # Durcit la stratégie ProConnect de la gem 0.6 :
    #  - demande explicitement le claim `amr` (paramètre `claims`) — la gem ne le fait pas ;
    #  - expose l'id_token brut (credentials) et le nonce émis (extra) dans le auth hash,
    #    pour que Portail::Sessions::Create vérifie signature + nonce côté app.
    class ProconnectHardened < Proconnect
      option :name, "proconnect"

      credentials do
        {id_token: session["omniauth.pc.id_token"]}
      end

      extra do
        {raw_info: @userinfo, nonce: session["omniauth.nonce"]}
      end

      private

      def authorization_uri
        URI(discovered_configuration["authorization_endpoint"]).tap do |endpoint|
          endpoint.query = URI.encode_www_form(
            response_type: "code",
            client_id: options[:client_id],
            redirect_uri: options[:redirect_uri],
            scope: options[:scope],
            state: store_new_state!,
            nonce: store_new_nonce!,
            claims: {id_token: {amr: {essential: true}}}.to_json
          )
        end
      end
    end
  end
end
