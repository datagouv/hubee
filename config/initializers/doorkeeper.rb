# Serveur OAuth2 de l'API V2, réduit au flux machine `client_credentials`.
Doorkeeper.configure do
  orm :active_record

  # Aucun flux à interaction humaine : ce bloc ne doit jamais être appelé.
  resource_owner_authenticator do
    raise Doorkeeper::Errors::DoorkeeperError, "resource owner flows are disabled"
  end

  api_only

  grant_flows %w[client_credentials]

  access_token_expires_in 2.hours

  # Secret client et tokens illisibles en base ; communiqués une seule fois.
  hash_application_secrets
  hash_token_secrets
end
