# Hubee V2 - API REST

**Version**: 1.2.0 | **Base URL**: `/api`, suivi de l'espace et de sa version (`/api/internal/v1`) :
voir « Versionnage ». `/api/v1` est l'ébauche gelée décrite plus bas.

## Philosophie

- **RESTful** + **JSON** (Jbuilder) + **Bearer Auth** + **Rails Scaffold Style**
- **Flat Responses** : index = array direct, show = objet direct
- **Nesting Policy** :
  - ❌ **has_many** : jamais nester (évite explosion payload)
  - ✅ **belongs_to** : peut être nesté (1 objet, évite requêtes multiples)
  - Exception historique : `attachments` nested dans `data_packages` (has_many)
- **Pagination** : Headers HTTP (X-Page, X-Total), body reste array direct
- **Autorisations** : (r) = read, (w) = write
- **IDs API** : UUIDs v4 partout (primary keys), SIRET conservé comme attribut métier des Organizations

## Versionnage

La version majeure fait partie du chemin, après l'espace : `/api/<espace>/v<N>/…`, servi par le
module `API::<Espace>::V<N>` (par exemple `/api/internal/v1/…` et `API::Internal::V1`). Une
version qui n'existe pas répond la 404 d'une URL inconnue. Une spec de routage refuse toute route
sous `/api` qui n'a pas cette forme, hors de ce qui reste commun à toutes les versions.

Dans une version, on n'apporte que des changements compatibles. Une rupture crée la version
suivante.

Chaque nouvelle version duplique le code de la précédente : les contrôleurs, base de l'espace
comprise, les forms, les interactors et leurs étapes, les policies, les vues, les helpers s'il y en
a, et leurs specs.

Restent communs à toutes les versions, sans numéro :

- `API::BaseController`, `API::ErrorsController` et la 404 de toute URL inconnue sous `/api` ;
- `POST /api/oauth/token` et `GET /api/ping` ;
- `API::HubAPI`, les modèles et les jobs ;
- les messages `api.errors.*` ;
- les droits d'un client OAuth : un droit vaut pour toutes les versions.

Les endpoints gelés décrits plus bas, sous `/api/v1`, ne suivent pas encore cette règle. Ce `v1`
est celui de l'ébauche de l'API V2 : il n'a rien à voir avec l'API V1 en production.

## Authentification & Autorisations

**Bearer Token** : `Authorization: Bearer <token>`, seul emplacement lu. Un jeton passé dans l'URL
(`access_token`, `bearer_token`) ou dans le corps est ignoré : la requête reçoit 401, comme sans
jeton. Un proxy journalise l'URL, donc le jeton qui y serait (RFC 6750 § 2.3).
- Délivrance : `POST /api/oauth/token`, OAuth2 `client_credentials`, identifiants du client dans le
  corps ou en HTTP Basic ; jeton valable 2 heures, stocké haché, communiqué une seule fois
- Droits **(r)** / **(w)** : prévus pour les endpoints gelés, non appliqués

## Espace interne (`/api/internal`)

Réservé aux systèmes internes de la plateforme, dont hub-api, jamais exposé à l'API publique.
Avec `/api/ping` et l'émission du jeton, c'est la seule partie de l'API en service ; les
endpoints décrits plus bas restent gelés.

**Authentification** : jeton OAuth2 `client_credentials` (`POST /api/oauth/token`), demandé
**sans `scope`**, puis `Authorization: Bearer <token>`. Un `scope`, même le nom d'un droit, fait
refuser le jeton (400 `invalid_scope`).

Les refus de `POST /api/oauth/token` suivent OAuth2 : `{"error": "<code>", "error_description": "…"}`.

| Statut | `error` | Quand |
|--------|---------|-------|
| 400 | `invalid_request` | `grant_type` absent |
| 400 | `unsupported_grant_type` | `grant_type` autre que `client_credentials` |
| 400 | `invalid_scope` | un `scope` demandé |
| 401 | `invalid_client` | client inconnu, secret faux ou absent, sans distinction |

Un corps JSON illisible y reçoit le 400 général, `{"error": "bad_request", "message": "La requête est mal formée."}`.

**Droits** : accordés au client, opération par opération (voir `docs/RUNBOOK.md`). Ils ne
passent pas par le jeton : ils sont lus à chaque appel, et un client sans le droit reçoit 403 `forbidden`.

### Enregistrer un agent

```http
POST /api/internal/v1/agents        # droit internal:agents:create
```

Crée l'agent s'il est inconnu, le rattache s'il est déjà connu (même adresse) pour une autre
organisation. Son identité n'est alors pas modifiée : c'est ProConnect qui la rafraîchit à la
connexion. L'organisation est vérifiée au référentiel V1 (organisation de type SI) à chaque
appel, même connue de la V2, puis prise en compte si elle est nouvelle. Un seul rattachement par appel : un agent de deux organisations
donne deux appels.

```json
{
  "agent": {
    "email": "alice.martin@ville.fr",
    "first_name": "Alice",
    "last_name": "Martin",
    "civility": "ms",
    "send_invitation": true,
    "membership": {
      "siret": "21750056000016",
      "insee_code": "75056",
      "role": "member",
      "job_title": "Officier d'état civil",
      "phone_number": "+33123456789",
      "mobile_phone_number": "+33612345678",
      "data_stream_codes": ["CERTDC"]
    }
  }
}
```

| Champ | Obligatoire | Règle |
|-------|-------------|-------|
| `email` | oui | adresse de l'agent, sans distinction de casse : c'est elle que la connexion ProConnect retrouve |
| `first_name`, `last_name` | oui | |
| `civility` | non | `mr` ou `ms` |
| `send_invitation` | non | `true` ou `false` JSON, `false` si absent : demande l'invitation de l'agent. Toute autre valeur (`"true"`, `1`, `null`, `""`, une liste…) est refusée (422). Lu dans le corps JSON seul : passé dans l'URL ou un formulaire, il est ignoré. La réponse ne change pas |
| `membership.siret` | oui | 14 chiffres |
| `membership.insee_code` | oui | le **code guichet** de l'organisation. Avec le SIRET, il la désigne sans ambiguïté, même quand plusieurs organisations partagent un SIRET. C'est son code INSEE, que le référentiel V1 appelle code de branche |
| `membership.role` | oui | `member` ou `local_administrator`, jamais déduit d'une valeur par défaut |
| `membership.job_title` | non | 255 caractères au plus |
| `membership.phone_number`, `membership.mobile_phone_number` | non | format E.164 (`+33123456789`) ; un numéro national français est mis en forme, tout autre numéro mal formé est refusé |
| `membership.data_stream_codes` | oui | une liste de chaînes, toujours fournie : une liste absente, `null`, un élément `null` ou toute autre forme sont refusés. Au moins un code pour un `member` ; une liste vide (`[]`) donne à un `local_administrator` l'accès à tous les flux de son organisation (hub-api l'envoie ainsi pour l'administrateur local déclaré à l'abonnement). Un code compte de 1 à 100 caractères, accents compris, sans aucun espacement (espace insécable comprise), une fois retirés les espaces en bord (`" CERTDC"` vaut `CERTDC`) ; il est un identifiant opaque : les doublons exacts sont retirés, la casse n'est jamais changée (`CERTDC` et `certdc` sont deux codes). 100 codes distincts au plus (51 codes en production au 26/10/2026). Chaque code doit être connu de hub-api sous ce code exact (une reconnaissance vaut une heure) : un seul code inconnu refuse tout l'appel, et chaque code inconnu est cité dans son motif. Un code mal formé est refusé avant toute vérification : tant qu'il en reste un, hub-api n'est interrogé sur aucun code, et les codes inconnus ne sont cités qu'une fois les codes mal formés corrigés. Les codes sont vérifiés même quand le référentiel des organisations ne répond pas, dans l'ordre transmis, jusqu'à la première panne de hub-api : les suivants ne sont examinés qu'au prochain appel |

L'invitation part en différé, après l'enregistrement, et seulement quand l'appel crée l'agent et demande
l'invitation (`send_invitation: true`). Elle ne part ni sur un rejeu, ni pour un agent déjà connu rattaché à
une nouvelle organisation, ni sur un refus ; la réponse n'en dépend pas, même si l'envoi échoue ensuite.

**201** : l'état enregistré, pas l'état demandé (pour un agent connu ailleurs, l'identité
retenue). `id` désigne l'agent dans les opérations suivantes ; l'identifiant ProConnect n'est
jamais exposé.

```json
{
  "id": "0199…",
  "email": "alice.martin@ville.fr",
  "first_name": "Alice",
  "last_name": "Martin",
  "civility": "ms",
  "membership": {
    "siret": "21750056000016",
    "insee_code": "75056",
    "role": "member",
    "job_title": "Officier d'état civil",
    "phone_number": "+33123456789",
    "mobile_phone_number": "+33612345678",
    "data_stream_codes": ["CERTDC"]
  }
}
```

**Erreurs.** Les motifs qui portent sur un champ reprennent l'imbrication de la demande, sans
l'enveloppe `agent` : un motif sur un champ du rattachement apparaît sous `membership`. Les
erreurs sans champ ont la forme commune à l'API, `{"error": "<code>", "message": "…"}` (section
« Erreurs », plus bas). Les messages sont en français.

```json
{
  "email": ["désigne un agent déjà rattaché à cette organisation"],
  "membership": {"phone_number": ["n'est pas valide"]}
}
```

Une demande refusée reçoit **tous** ses motifs à la fois, chacun sur son champ. Le statut est
celui du motif le plus fort : un conflit (409) l'emporte sur une demande invalide (422). Un
référentiel indisponible (503) n'est signalé que s'il n'y a aucun autre motif. Un refus n'écrit
rien, ni agent, ni organisation, ni rattachement, ni trace.

Les contrôles se suivent dans cet ordre, et le premier qui refuse donne la réponse :

| Ordre | Contrôle | Refus |
|-------|----------|-------|
| 1 | jeton | 401 |
| 2 | droit du client | 403, même si le corps est illisible |
| 3 | corps lisible, enveloppe `agent` présente | 400 |
| 4 | motifs de la demande : champs, référentiel, rattachements existants | 409, sinon 422, tous les motifs à la fois |
| 5 | référentiel joignable | 503, seulement sans aucun motif |

Des paramètres d'URL mal formés sont refusés (400) avant tout contrôle, jeton compris.

| Statut | Quand | Corps |
|--------|-------|-------|
| 400 | corps illisible (JSON mal formé) | `{"error": "bad_request", "message": "…"}` |
| 400 | enveloppe `agent` absente | `{"error": "missing_agent", "message": "…"}` |
| 401 | jeton absent, inconnu, expiré ou révoqué | `{"error": "invalid_token", "message": "…"}` |
| 403 | client sans le droit `internal:agents:create` | `{"error": "forbidden", "message": "…"}` |
| 404 | autre méthode que `POST` | `{"error": "not_found", "message": "…"}` |
| 409 | agent déjà rattaché à cette organisation, pour **tout** rejeu, identique ou non : rien n'est modifié, et l'état enregistré n'est pas renvoyé | motif sur `email` |
| 409 | agent déjà rattaché à ce SIRET sous un autre code guichet (un seul rattachement par SIRET) | motif sur `membership.insee_code` |
| 422 | champ manquant ou invalide | motif sur chaque champ concerné |
| 422 | organisation inconnue du référentiel V1 | motif sur `membership.siret` |
| 422 | code de flux inconnu de hub-api | un motif par code inconnu sur `membership.data_stream_codes`, qui le cite |
| 503 | référentiel V1 (hub-api) injoignable ou incohérent, pour l'organisation comme pour un code de flux : réessayable, sans en-tête `Retry-After` | `{"error": "service_unavailable", "message": "…"}` |

Chaque écriture laisse sa trace (`agent.created` si l'agent est créé, `membership.created`) : le
client appelant (nom et uid), la requête, l'adresse, l'organisation, le rôle et les habilitations ;
`agent.created` porte en plus `send_invitation`, sa valeur effective.
L'identifiant de la requête est celui que le client envoie dans `X-Request-Id` (255 caractères au plus,
lettres, chiffres, `-`, `_` et `@`), à défaut un UUID généré par le serveur : il sert à recouper les
journaux, pas à prouver l'origine d'un appel.

## Endpoints (Rails Scaffold Style)

**Pattern de réponse universel** :
- **index** : `[{...}, {...}]` (array direct)
- **show** : `{...}` (objet direct)
- **create/update** : `{...}` (objet créé/modifié)
- Pas de wrapper sauf `attachments` dans `data_packages`

### Organizations

```http
GET    /api/v1/organizations              # index → [{id: uuid, name, siret, created_at}, ...]
GET    /api/v1/organizations/:id          # show  → {id: uuid, name, siret, created_at}
POST   /api/v1/organizations               # (admin futur)
PUT    /api/v1/organizations/:id          # (admin futur)
DELETE /api/v1/organizations/:id          # (admin futur)
```

**Note** : `id` (UUID) est l'identifiant primaire. SIRET conservé comme attribut métier unique. Routes utilisent `:id` comme param (convention REST standard).

### Data Streams (r/w)

```http
GET    /api/v1/data_streams              # index → [{id: uuid, name, description, owner_organization: {id, name, siret, ...}, retention_days, created_at}, ...]
POST   /api/v1/data_streams         (w)  # create → {id: uuid, ...} | body: {data_stream: {name, description, owner_organization_id: uuid, retention_days}}
GET    /api/v1/data_streams/:id        # show  → {id: uuid, name, description, owner_organization: {id, name, siret, ...}, retention_days, created_at}
PUT    /api/v1/data_streams/:id   (w)  # update → {id: uuid, ...}
DELETE /api/v1/data_streams/:id   (w)  # 204 (si aucune notification existante)
```

**Notes** :
- `owner_organization` est **nested** (belongs_to) pour éviter requêtes multiples
- L'update permet de changer `owner_organization_id` (transfert de propriété du data stream entre organisations)
- `retention_days` accepte `null` (pas de limite de rétention)

### Subscriptions (r/w)

```http
GET    /api/v1/organizations/:id/subscriptions  # index (admin-only) → [{id: uuid, data_stream_id: uuid, organization: {id, name, siret}, can_read: bool, can_write: bool, created_at}, ...]
GET    /api/v1/data_streams/:id/subscriptions    # index → [{id: uuid, ..., organization: {...}, can_read: bool, can_write: bool}, ...]
POST   /api/v1/data_streams/:id/subscriptions    # create → {id: uuid, ...} | body: {subscription: {organization_id: uuid, can_read: bool, can_write: bool}}
GET    /api/v1/subscriptions/:id                 # show → {id: uuid, data_stream_id: uuid, organization: {id, name, siret}, can_read: bool, can_write: bool, created_at}
PUT    /api/v1/subscriptions/:id                 # update → {id: uuid, ...} | body: {subscription: {can_read: bool, can_write: bool}}
DELETE /api/v1/subscriptions/:id                 # 204
GET    /api/v1/data_packages/:id/subscriptions   # index → {subscriptions: [...], source: "resolver"|"notifications", delivery_criteria: {...}} + pagination headers
```

**Boolean Permissions** : `can_read` et `can_write` (au moins un doit être `true`)

**Exemples de permissions** :
```json
{"can_read": true, "can_write": false}   // Lecture seule
{"can_read": false, "can_write": true}   // Écriture seule
{"can_read": true, "can_write": true}    // Lecture et écriture
```

**Filtres par permissions** :
```http
GET /api/v1/organizations/:id/subscriptions?can_read=true           # Toutes avec can_read=true
GET /api/v1/organizations/:id/subscriptions?can_write=true          # Toutes avec can_write=true
GET /api/v1/organizations/:id/subscriptions?can_read=true&can_write=true  # Seulement lecture ET écriture
GET /api/v1/organizations/:id/subscriptions?can_read=false          # Toutes avec can_read=false (écriture seule)
GET /api/v1/organizations/:id/subscriptions?can_write=false         # Toutes avec can_write=false (lecture seule)
```

**Data Package Subscriptions** (Prévisualisation/Historique) :
```http
GET /api/v1/data_packages/:id/subscriptions
```
- **Draft package** : utilise `DeliveryCriteria::Resolver` pour prévisualiser les subscriptions ciblées
- **Transmitted/Acknowledged package** : retourne les subscriptions via les notifications existantes
- Response inclut `source` ("resolver" ou "notifications") pour indiquer la source

**Notes** :
- `organization` est **nested** (belongs_to) pour éviter requêtes multiples
- Endpoint `/organizations/:id/subscriptions` = admin-only (Feature 9: Authentication)
- CASCADE DELETE : Subscriptions supprimées automatiquement si data_stream ou organization supprimés
- Validation : au moins une permission doit être accordée (`can_read` ou `can_write` = true)
- Filtres acceptent `true`/`false` comme strings (ex: `?can_read=true`)

### Data Packages (r/w) - Exception : attachments nested

```http
GET    /api/v1/data_packages                         # index → [{id: uuid, data_stream_id: uuid, sender_organization_id: uuid, status, title, sent_at, created_at}, ...]
GET    /api/v1/data_streams/:id/data_packages      # index (producteur: tous | consommateur: notifiés uniquement)
POST   /api/v1/data_streams/:id/data_packages (w)  # create → {id: uuid, ...} | body: {data_package: {title, target_organization_ids: [uuid, ...]}}
GET    /api/v1/data_packages/:id                   # show  → {id: uuid, ..., attachments: [{id: uuid, filename, byte_size, processing_status}, ...]}
PUT    /api/v1/data_packages/:id               (w) # update → {id: uuid, ...} (changement title uniquement)
DELETE /api/v1/data_packages/:id               (w) # 204 (si aucune notification existante)
POST   /api/v1/data_packages/:id/send          (w) # {id: uuid, ...} (transitions: ready → sent, crée notifications)
```

**Filters** : `?status=draft|ready|sent|acknowledged&data_stream_id=<uuid>`
**⚠️ Exception unique** : `attachments` array nested dans le show (avec UUIDs)

**Delivery Criteria** (ciblage des notifications) :
```json
// Critères supportés
{
  "siret": "13002526500013",           // SIRET unique ou array
  "organization_id": "uuid",            // UUID organization ou array
  "subscription_id": "uuid"             // UUID subscription ou array
}

// Opérateurs logiques
{
  "_or": [                              // Union des résultats
    {"siret": "13002526500013"},
    {"organization_id": "uuid"}
  ]
}

{
  "_and": [                             // Intersection des résultats
    {"siret": "13002526500013"},
    {"organization_id": "uuid"}
  ]
}

// Critères multiples (AND implicite)
{
  "siret": "13002526500013",
  "organization_id": "uuid"             // Doit satisfaire les deux
}
```

**Limites** :
- **Max profondeur** : 2 niveaux de nesting (ex: `_or` → `_and` → leaf)
- **Max critères** : 20 critères total (comptés dans les feuilles)
- **Validation** : Structure validée à la création du data_package

### Attachments (w pour POST/DELETE, r/w pour GET)

```http
POST   /api/v1/data_packages/:id/attachments  (w)      # 202 → {id: uuid, filename, processing_status: "pending", data_package_id: uuid, created_at}
GET    /api/v1/attachments/:id                         # show → {id: uuid, filename, processing_status, byte_size, virus_scan_result, encrypted, retry_count, data_package_id: uuid, created_at}
DELETE /api/v1/attachments/:id                 (w)      # 204
GET    /api/v1/attachments/:id/download                # 302 Redirect → S3 signed URL
GET    /api/v1/data_packages/:id/attachments/download  # Download all (ZIP)
POST   /api/v1/attachments/:id/retry          (w)      # Re-enqueue si status = scan_failed/encryption_failed/upload_failed
```

**Upload** : `multipart/form-data` + `file`, `filename`, `checksum: "sha256:abc..."`
**Processing states** : `pending → scanning → encrypting → uploading → completed` (ou `*_failed`)
**Note** : `id` exposé = UUID. `data_package_id` = UUID.

### Notifications (r/w)

```http
GET    /api/v1/notifications                        # index → [{id: uuid, data_package_id: uuid, subscription_id: uuid, organization_id: uuid, status, sent_at, acknowledged_at, created_at}, ...]
GET    /api/v1/data_streams/:id/notifications     # index (filter par stream)
GET    /api/v1/notifications/:id                  # show  → {id: uuid, data_package_id: uuid, subscription_id: uuid, organization_id: uuid, status, sent_at, acknowledged_at, created_at}
POST   /api/v1/notifications/:id/acknowledge      # {id: uuid, ...} (transitions: sent → acknowledged)
```

**Filters** : `?status=pending|sent|acknowledged&data_stream_id=<uuid>`
**Note** : `id` exposé = UUID. Relations : `data_package_id` = UUID, `organization_id` = UUID.

### Users

```http
GET    /api/v1/users                         # index → [{id: uuid, email, name, created_at}, ...]
GET    /api/v1/users/:id                   # show  → {id: uuid, email, name, created_at}
GET    /api/v1/organizations/:id/users    # index (users d'une org)
GET    /api/v1/users/:id/organizations     # index (orgs d'un user : [{id: uuid, name, siret, ...}]) - pas nested
POST   /api/v1/users                         # (admin futur)
PUT    /api/v1/users/:id                   # (admin futur)
DELETE /api/v1/users/:id                   # (admin futur)
```

**Note** : `id` exposé = UUID.

## Pagination (Pagy)

**Query** : `?page=1&per_page=50` (défaut 50, max 100)
**Headers** : `X-Page`, `X-Per-Page`, `X-Total`, `X-Total-Pages`
**Body** : Array direct (pas de meta dans body)

## Erreurs

Toute erreur sous `/api` répond en JSON, jamais par une page du portail, sous la forme
`{"error": "<code>", "message": "<phrase>"}`. Le code est stable : c'est lui qu'un programme lit.
La phrase, en français, s'adresse à une personne et peut changer ; elle montre aussi que la
réponse vient de l'application, et non d'un composant placé en amont.

| Statut | `error` | `message` | Quand |
|--------|---------|-----------|-------|
| 400 | `bad_request` | La requête est mal formée. | corps JSON illisible, paramètres d'URL mal formés |
| 401 | `invalid_token` | Le jeton d'accès est absent, inconnu, expiré ou révoqué. | jeton absent, inconnu, expiré ou révoqué, sans distinction ; en-tête `WWW-Authenticate: Bearer …` |
| 404 | `not_found` | Ressource introuvable. | URL inconnue sous `/api`, ou méthode non servie ; ressource introuvable |
| 500 | `internal_server_error` | Une erreur est survenue. | erreur inattendue |

Une exception à laquelle Rails donne un autre statut (409, 422…) le garde, avec le nom de ce
statut pour code (`conflict`, `unprocessable_content`…) et la phrase de la 500. Les erreurs
propres à un endpoint sont décrites avec lui ; `POST /api/oauth/token` suit OAuth2 (`error`,
`error_description`).

Deux écarts à RFC 6750 § 3.1, acceptés : sans jeton, l'en-tête annonce quand même
`error="invalid_token"` (la RFC recommande de n'y mettre aucun code) ; les caractères non ASCII de
`error_description` y deviennent `_`.

Les endpoints gelés (`/api/v1`) prévoyaient d'autres réponses (403 sur les droits (r)/(w), 422
`{champ: […]}`, limite de débit en 429) : rien de cela n'est en service.

## Code Style & Patterns

**Voir** : `.ai/context/CODE_STYLE.md` pour :
- Patterns Jbuilder (partials, flat responses, identifiants)
- Controllers (params.expect, find_by!, error handling)
- Models (delegates, validations, associations)
- Tests (RSpec patterns, factories)

**Identifiants API** :
- Toutes les ressources : UUID v4 exposé comme `id` (primary key, généré par `gen_random_uuid()`)
- Organizations : `siret` conservé comme attribut métier unique (14 chiffres)
- Relations : Toujours par UUID (`organization_id`, `data_stream_id`, etc.)

## Workflow Exemple : Producteur → Consommateur

```bash
# Producteur (Organization UUID: <org-uuid-1>)
POST /api/v1/data_packages {data_stream_id: "<uuid>", title: "..."} → {id: "<uuid>", status: "draft"}
POST /api/v1/data_packages/<uuid>/attachments (multipart)           → {id: "<uuid>", processing_status: "pending"}
GET  /api/v1/attachments/<uuid> (polling)                           → {processing_status: "completed"}
POST /api/v1/data_packages/<uuid>/send                              → {id: "<uuid>", status: "sent"} + notifications créées

# Consommateur (Organization UUID: <org-uuid-2>)
GET  /api/v1/notifications?status=sent                              → [{id: "<uuid>", data_package_id: "<uuid>", organization_id: "<org-uuid-2>", ...}]
GET  /api/v1/data_packages/<uuid>                                   → {id: "<uuid>", sender_organization_id: "<org-uuid-1>", attachments: [{id: "<uuid>", ...}]}
GET  /api/v1/attachments/<uuid>/download                            → 302 → S3 signed URL
POST /api/v1/notifications/<uuid>/acknowledge                       → {id: "<uuid>", status: "acknowledged"}
```
