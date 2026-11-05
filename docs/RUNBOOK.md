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

Un client délivré ainsi n'a aucun droit : seul `/api/ping` lui répond. Ne lui
accorder que les droits dont il a besoin.

### Droits d'un client

| Droit | Opération | Destinataires |
|-------|-----------|---------------|
| `internal:agents:create` | `POST /api/internal/v1/agents` | systèmes internes, dont hub-api |

hub-api ne reçoit que `internal:agents:create`. Ce droit n'est délivré à aucun client
tant que l'enregistrement ne vérifie pas les codes de flux auprès de hub-api :
jusque-là, un code inconnu serait enregistré.

    app = Doorkeeper::Application.find_by!(name: "nom-du-client")
    OauthApplicationRight.create!(oauth_application: app, right: "internal:agents:create")  # accorder
    OauthApplicationRight.find_by!(oauth_application: app, right: "internal:agents:create").destroy!  # retirer

Les droits sont lus à chaque appel : le changement vaut immédiatement, y compris
pour les jetons déjà délivrés. Un droit hors de `OauthApplicationRight::RIGHTS`
est refusé (faute de frappe).

Les droits ne sont pas des scopes OAuth : le client demande toujours son jeton
**sans `scope`**. Un `scope`, même le nom d'un droit, fait refuser le jeton
(400 `invalid_scope`).

### Révoquer un accès (effet immédiat)

    Doorkeeper::Application.find_by!(name: "nom-du-client").destroy!

Détruit le client, ses credentials, ses droits et tous ses tokens en cours.

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
