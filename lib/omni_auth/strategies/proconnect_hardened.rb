# frozen_string_literal: true

require "omniauth/proconnect"

module OmniAuth
  module Strategies
    # Durcit la stratégie ProConnect de la gem 0.6 :
    #  - demande explicitement `amr` (paramètre `claims`) et `acr` (`acr_values`) — la gem
    #    ne demande ni l'un ni l'autre, et ProConnect ne les émet pas spontanément ;
    #  - expose l'id_token brut (credentials) et le nonce émis (extra) dans le auth hash,
    #    pour que Portail::Sessions::Create vérifie signature + nonce côté app.
    class ProconnectHardened < Proconnect
      option :name, "proconnect"

      # Le plancher demandé à ProConnect, aligné sur le premier niveau que le portail
      # accepte. Voir Portail::Sessions::Create::CheckAuthenticationLevel.
      MINIMUM_AUTHENTICATION_LEVEL = "eidas1"

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
            claims: {id_token: {amr: {essential: true}}}.to_json,
            # Sans `acr_values`, ProConnect n'émet aucun `acr` — le demander via `claims`
            # ne suffit pas — et CheckAuthenticationLevel refuserait alors tout le monde.
            # La valeur annonce notre minimum ; elle ne dispense pas de vérifier le niveau
            # réellement atteint au retour, seul contrôle qui fasse foi.
            acr_values: MINIMUM_AUTHENTICATION_LEVEL
          )
        end
      end
    end
  end
end
