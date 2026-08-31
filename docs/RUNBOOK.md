# Runbook

Gestes d'exploitation de l'application. Dépôt public : aucune valeur réelle ici.

## Clients API (OAuth2 `client_credentials`)

Les accès des systèmes clients de l'API V2 se gèrent en console Rails.

### Délivrer un accès

    app = Doorkeeper::Application.create!(name: "nom-du-client")
    app.uid              # => client_id
    app.plaintext_secret # => client_secret — affiché UNE SEULE FOIS

Transmettre `uid` et `plaintext_secret` par un canal sûr. Le secret est hashé
en base : il n'est plus relisible ensuite (en cas de perte → rotation).

### Révoquer un accès (effet immédiat)

    Doorkeeper::Application.find_by!(name: "nom-du-client").destroy!

Détruit le client, ses credentials et tous ses tokens en cours.

### Renouveler un secret (rotation)

    app = Doorkeeper::Application.find_by!(name: "nom-du-client")
    app.renew_secret
    app.save!
    app.plaintext_secret # => nouveau secret — affiché UNE SEULE FOIS

Même `client_id`, nouveau secret. L'ancien secret est refusé immédiatement ;
les tokens déjà délivrés restent valides jusqu'à expiration (2 h max).

### Purge des tokens morts

Automatique : un job récurrent quotidien supprime les tokens expirés ou révoqués
(`purge_api_access_tokens`, `config/recurring.yml`). Aucun geste à faire.

### Vérifier des credentials (côté client)

    curl -s -X POST https://<hôte>/api/oauth/token -d "grant_type=client_credentials" -d "client_id=<uid>" -d "client_secret=<secret>"
    curl -s https://<hôte>/api/ping -H "Authorization: Bearer <access_token>"

## Limites de débit

Deux limites, par minute glissante :

- `/api/oauth/token` : 10 requêtes/minute (`API::TokensController::RATE_LIMIT_PER_MINUTE`), par IP.
- Le reste de l'API : 300 requêtes/minute (`API::BaseController::RATE_LIMIT_PER_MINUTE`), par jeton (ou IP si absent).

Un `429` est réessayable après une minute : le client ne doit jamais l'avaler
en silence, mais le réémettre après ce délai.
