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

      # ProConnect renvoie ses refus en paramètre. La gem ne les lit pas et enchaîne
      # l'échange du code, qui échoue plus loin sous un motif trompeur : les journaux
      # parlent alors de décodage JWT là où il faudrait lire le refus lui-même.
      def callback_phase
        return fail!(request.params["error"]) if request.params["error"].present?

        super
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
            claims: requested_claims,
            # Sans `acr_values`, ProConnect n'émet aucun `acr` — le demander via `claims`
            # ne suffit pas — et CheckAuthenticationLevel refuserait alors tout le monde.
            # La valeur annonce notre minimum ; elle ne dispense pas de vérifier le niveau
            # réellement atteint au retour, seul contrôle qui fasse foi.
            acr_values: MINIMUM_AUTHENTICATION_LEVEL
          )
        end
      end

      # Le second facteur se demande par `claims`, comme le prescrit la doc ProConnect —
      # `acr_values` n'annonce qu'un plancher et n'oblige à rien. `essential: true` fait
      # renvoyer une erreur si ProConnect ne peut pas satisfaire, plutôt qu'un niveau plus
      # faible : `callback_phase` la lit déjà.
      def requested_claims
        claims = {id_token: {amr: {essential: true}}}
        claims[:id_token][:acr] = {essential: true, values: Portail::SecondFactor::LEVELS} if stepping_up?
        claims.to_json
      end

      # Marqué par le contrôleur au retour du premier callback. Jamais un paramètre de
      # requête : c'est l'application qui décide du niveau exigé, pas l'appelant.
      def stepping_up?
        session["proconnect_step_up"].present?
      end
    end
  end
end
