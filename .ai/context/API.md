# Hubee V2 - API REST

**Version**: 1.2.0 | **Base URL**: `/api/v1`

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

## Authentification & Autorisations

**Bearer Token** : `Authorization: Bearer <token>`
- Génération : `organization.generate_api_token(name: 'API Prod')` (retourné UNE FOIS)
- Stockage : SHA256 digest + expiration + last_used_at
- Droits : **(r)** = read (abonné lecture), **(w)** = write (abonné écriture/owner)

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

## Errors & Rate Limiting

| Code | Type | Response |
|------|------|----------|
| 401 | Unauthorized | `{error: "message"}` - Token invalide/expiré |
| 403 | Forbidden | `{error: "message"}` - Droits insuffisants |
| 404 | Not Found | `{error: "Not found"}` |
| 422 | Unprocessable Entity | `{field: ["error1", "error2"]}` - Validation errors (direct, no wrapper) |
| 429 | Too Many Requests | `{error: "message"}` - Rate limit (headers: X-RateLimit-*) |
| 500 | Internal Server Error | `{error: "message"}` - Erreur serveur |

**Rate Limits (Rack::Attack)** :
- Par IP : 300 req/5min
- Par token : 1000 req/h

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
