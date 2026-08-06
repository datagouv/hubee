# frozen_string_literal: true

# Câblage du client OIDC. Le gem sait découvrir l'annuaire ProConnect et récupérer ses
# clés publiques, mais il ne met rien en cache par défaut : sa classe Cache est un
# passe-plat qui refait l'appel HTTP à chaque vérification de jeton. On lui confie le nôtre.
#
# Le cache du JWKS est indexé par `kid` : une clé inconnue est un défaut de cache, donc un
# rechargement immédiat. C'est le comportement anti-rotation qu'on entretenait à la main,
# en plus fin — on rechargeait le jeu entier, lui ne va chercher que ce qui manque.
# Exigé, non déduit de la valeur fournie : récupérées en clair, les clés publiques de
# ProConnect pourraient être remplacées en chemin — la vérification de signature
# continuerait de passer, mais en validant les jetons de l'attaquant. Le gem, lui, se
# contente de vérifier que c'est une URL. Panne au démarrage plutôt qu'à la connexion.
unless ENV.fetch("PROCONNECT_DOMAIN", "").start_with?("https://")
  raise "PROCONNECT_DOMAIN doit être une URL HTTPS (reçu : #{ENV["PROCONNECT_DOMAIN"].inspect})"
end

module ProConnectCache
  # Résolu à l'appel et non au démarrage : `Rails.cache` est remplacé par les specs qui
  # éprouvent la mise en cache, et un magasin capturé ici les rendrait aveugles.
  def self.fetch(key, options = {}, &) = Rails.cache.fetch(key, options, &)

  def self.delete(key, options = {}) = Rails.cache.delete(key, options)
end

SWD.cache = ProConnectCache
JSON::JWK::Set::Fetcher.cache = ProConnectCache

# Sans ça, les délais par défaut de Faraday s'appliquent sur le chemin d'authentification :
# un ProConnect lent immobiliserait un worker Puma bien au-delà du raisonnable.
proconnect_timeouts = lambda do |faraday|
  faraday.options.open_timeout = 2
  faraday.options.timeout = 5
end

OpenIDConnect.http_config(&proconnect_timeouts)
JSON::JWK::Set::Fetcher.http_config(&proconnect_timeouts)
SWD.http_config(&proconnect_timeouts)
