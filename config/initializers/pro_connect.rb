# frozen_string_literal: true

# En clair, les clés publiques de ProConnect seraient substituables en chemin — panne au
# démarrage plutôt qu'à la connexion.
unless ENV.fetch("PROCONNECT_DOMAIN", "").start_with?("https://")
  raise "PROCONNECT_DOMAIN doit être une URL HTTPS (reçu : #{ENV["PROCONNECT_DOMAIN"].inspect})"
end

# Le gem ne met rien en cache par défaut : on lui confie Rails.cache. Le JWKS est indexé
# par `kid` — une clé inconnue est un défaut de cache, donc rechargée aussitôt (rotation).
module ProConnectCache
  # Résolu à l'appel : les specs remplacent Rails.cache.
  def self.fetch(key, options = {}, &) = Rails.cache.fetch(key, options, &)

  def self.delete(key, options = {}) = Rails.cache.delete(key, options)
end

SWD.cache = ProConnectCache
JSON::JWK::Set::Fetcher.cache = ProConnectCache

# Un ProConnect lent ne doit pas immobiliser un worker Puma.
proconnect_timeouts = lambda do |faraday|
  faraday.options.open_timeout = 2
  faraday.options.timeout = 5
end

OpenIDConnect.http_config(&proconnect_timeouts)
JSON::JWK::Set::Fetcher.http_config(&proconnect_timeouts)
SWD.http_config(&proconnect_timeouts)
