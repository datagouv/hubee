# Serveur OAuth2 de l'API V2, réduit au flux machine `client_credentials`.
Doorkeeper.configure do
  orm :active_record

  # Aucun flux à interaction humaine : ce bloc ne doit jamais être appelé.
  resource_owner_authenticator do
    raise Doorkeeper::Errors::DoorkeeperError, "resource owner flows are disabled"
  end

  api_only

  # Le jeton n'est lu que dans l'en-tête Authorization : dans l'URL, un proxy le journaliserait.
  access_token_methods :from_bearer_authorization

  grant_flows %w[client_credentials]

  access_token_expires_in 2.hours

  # Aucun scope : les droits d'un client sont dans OauthApplicationRight.

  # Secret client et tokens illisibles en base ; communiqués une seule fois.
  hash_application_secrets
  hash_token_secrets
end
