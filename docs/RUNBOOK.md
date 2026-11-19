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
| `internal:agents:create` | `POST /api/internal/v1/agents` | systèmes internes, dont hub-api ; admin-portal |
| `internal:agents:read` | lister et consulter les agents | admin-portal |
| `internal:agents:update` | modifier un agent et ses rattachements | admin-portal |
| `internal:agents:destroy` | supprimer un agent | admin-portal |

hub-api ne reçoit que `internal:agents:create`, et aucun autre droit.
L'enregistrement et la modification des habilitations vérifient chaque code de
flux ajouté auprès de hub-api. Ces droits ne sont délivrés aux systèmes internes,
en recette comme en production, qu'une fois `/api/internal` réservé à leurs
adresses par le reverse proxy, en amont : l'application ne filtre pas par adresse.

Un droit par ligne, `<opération>` valant `create`, `read`, `update` ou `destroy` ;
admin-portal reçoit les quatre :

    app = Doorkeeper::Application.find_by!(name: "nom-du-client")
    OauthApplicationRight.create!(oauth_application: app, right: "internal:agents:<opération>")  # accorder
    OauthApplicationRight.find_by!(oauth_application: app, right: "internal:agents:<opération>").destroy!  # retirer

Les droits sont lus à chaque appel : le changement vaut immédiatement, y compris
pour les jetons déjà délivrés. Un droit hors de `OauthApplicationRight::RIGHTS`
est refusé (faute de frappe).

Les droits ne sont pas des scopes OAuth : le client demande toujours son jeton
**sans `scope`**. Un `scope`, même le nom d'un droit, fait refuser le jeton
(400 `invalid_scope`).

### Imputer une écriture à une personne

Une trace d'écriture de l'espace interne (`Event`) nomme le client (`api_client`,
`api_client_uid`), la requête (`request_id`) et, sous `declared_actor`, la
personne que le client déclare dans l'en-tête `X-Actor-Id`. Avant de délivrer
`create`, `update` ou `destroy` à admin-portal, s'assurer qu'il envoie, sur chaque
appel d'écriture :

- **`X-Actor-Id`** : l'identifiant stable de l'admin national dans admin-portal,
  jamais son adresse (1 à 255 caractères parmi `A-Z a-z 0-9 . _ : @ -`). Sans lui,
  la correction d'un agent, la modification ou le retrait d'un rattachement et la
  suppression d'un agent sont refusés en 400 `missing_actor` ; l'enregistrement
  l'accepte absent, pour hub-api qui appelle sans personne derrière.
- **`X-Request-Id`** : il relie la trace à la requête précise dans les journaux
  d'admin-portal.

Un traitement automatique sans personne derrière (job, reprise, synchronisation
côté client) envoie un identifiant explicite du traitement, préfixé, par exemple
`job:purge-comptes-inactifs` ; jamais un en-tête vide, ni l'identifiant d'une
personne qui n'a pas agi. Un traitement interne à HubEE n'appelle pas l'API et
n'est pas concerné.

Pour savoir qui a agi : lire `declared_actor` dans la trace, puis demander à
l'équipe d'admin-portal la personne qui porte cet identifiant. La trace se suffit
pendant toute sa conservation (un an), même si les journaux d'admin-portal ne sont
plus disponibles. Une trace d'enregistrement sans `declared_actor` vient d'un appel
sans personne déclarée (hub-api, typiquement).

La valeur est **déclarée par le client, non vérifiée** : l'API ne contrôle pas que
la personne existe ni qu'elle a agi. Elle n'étend pas la confiance accordée au
client (avec ces droits, il peut déjà tout modifier), mais elle ne prouve rien.
En cas de doute sur une écriture, recouper avec les journaux d'admin-portal par
`request_id`, s'ils sont encore conservés.

L'application garde l'identifiant de requête reçu, réduit aux lettres ASCII sans
accent, chiffres, `-`, `_` et `@` et tronqué à 255 caractères ; un en-tête que ce
nettoyage vide entièrement donne un identifiant vide, pas un UUID. Sans en-tête,
elle génère un UUID. Dans les deux cas, la trace ne se rattache à aucune requête
des journaux d'admin-portal. `X-Actor-Id`, lui, n'est jamais nettoyé : hors format,
l'appel est refusé. Vérifier aussi que le reverse proxy transmet les deux en-têtes
d'admin-portal **sans les remplacer** : l'application garde ce qui lui arrive.

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
