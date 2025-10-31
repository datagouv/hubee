# Hubee V2 - API REST

**Version**: 1.2.0 | **Base URL**: `/api/v1`

## Philosophie

- **RESTful** + **JSON** (Jbuilder) + **Bearer Auth** + **Rails Scaffold Style**
- **Flat Responses** : index = array direct, show = objet direct
- **Exception unique** : `attachments` nested dans `data_packages`
- **Pagination** : Headers HTTP (X-Page, X-Total), body reste array direct
- **Autorisations** : (r) = read, (w) = write
- **IDs API** : Identifiants naturels (SIRET exposé directement) ou UUIDs (colonne `uuid` auto-générée), jamais IDs séquentiels

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
GET    /api/v1/organizations              # index → [{name, siret, created_at}, ...]
GET    /api/v1/organizations/:siret        # show  → {name, siret, created_at}
POST   /api/v1/organizations               # (admin futur)
PUT    /api/v1/organizations/:siret        # (admin futur)
DELETE /api/v1/organizations/:siret        # (admin futur)
```

**Note** : SIRET est l'identifiant naturel unique. Routes utilisent `:siret` comme param. Pas d'`id` exposé.

### Data Streams (r/w)

```http
GET    /api/v1/data_streams              # index → [{id: uuid, name, description, owner_organization_siret, retention_days, created_at}, ...]
POST   /api/v1/data_streams         (w)  # create → {id: uuid, ...} | body: {data_stream: {name, description, retention_days}}
GET    /api/v1/data_streams/:uuid        # show  → {id: uuid, name, description, owner_organization_siret, retention_days, created_at}
PUT    /api/v1/data_streams/:uuid   (w)  # update → {id: uuid, ...}
DELETE /api/v1/data_streams/:uuid   (w)  # 204 (si aucune notification existante)
```

**Notes** :
- L'update permet de changer `owner_organization_siret` (transfert de propriété du data stream entre organisations)
- `retention_days` accepte `null` (pas de limite de rétention)

### Subscriptions (r/w)

```http
GET    /api/v1/organizations/:siret/subscriptions  # index (admin-only) → [{id: uuid, data_stream_id: uuid, organization_id: siret, permission_type, created_at}, ...]
GET    /api/v1/data_streams/:uuid/subscriptions    # index → filtre: ?permission_type=read,read_write
POST   /api/v1/data_streams/:uuid/subscriptions    # create → {id: uuid, ...} | body: {subscription: {organization_id: siret, permission_type}}
GET    /api/v1/subscriptions/:uuid                 # show → {id: uuid, data_stream_id: uuid, organization_id: siret, permission_type, created_at}
PUT    /api/v1/subscriptions/:uuid                 # update → {id: uuid, ...} | body: {subscription: {permission_type}}
DELETE /api/v1/subscriptions/:uuid                 # 204
```

**Enum `permission_type`** : `"read"` | `"write"` | `"read_write"`

**Filtre par permission_type** (valeurs séparées par virgules) :
```http
GET /api/v1/data_streams/:uuid/subscriptions?permission_type=read,read_write  # Toutes avec read OU read_write
GET /api/v1/data_streams/:uuid/subscriptions?permission_type=write,read_write # Toutes avec write OU read_write
GET /api/v1/data_streams/:uuid/subscriptions?permission_type=read_write       # Seulement read_write
GET /api/v1/data_streams/:uuid/subscriptions?permission_type=read             # Seulement read
GET /api/v1/data_streams/:uuid/subscriptions?permission_type=write            # Seulement write
GET /api/v1/data_streams/:uuid/subscriptions                                  # Toutes (pas de filtre)
```

**Notes** :
- `id` exposé = UUID. Relations : `data_stream_id` = UUID, `organization_id` = SIRET
- Endpoint `/organizations/:siret/subscriptions` = admin-only (Feature 9: Authentication)
- CASCADE DELETE : Subscriptions supprimées automatiquement si data_stream ou organization supprimés
- Filtre `permission_type` : liste de valeurs séparées par virgules, opérateur logique OR

### Data Packages (r/w) - Exception : attachments nested

```http
GET    /api/v1/data_packages                         # index → [{id: uuid, data_stream_id: uuid, sender_organization_id: siret, status, title, sent_at, created_at}, ...]
GET    /api/v1/data_streams/:uuid/data_packages      # index (producteur: tous | consommateur: notifiés uniquement)
POST   /api/v1/data_streams/:uuid/data_packages (w)  # create → {id: uuid, ...} | body: {data_package: {title, target_sirets: [...]}}
GET    /api/v1/data_packages/:uuid                   # show  → {id: uuid, ..., attachments: [{id: uuid, filename, byte_size, processing_status}, ...]}
PUT    /api/v1/data_packages/:uuid               (w) # update → {id: uuid, ...} (changement title uniquement)
DELETE /api/v1/data_packages/:uuid               (w) # 204 (si aucune notification existante)
POST   /api/v1/data_packages/:uuid/send          (w) # {id: uuid, ...} (transitions: ready → sent, crée notifications)
```

**Filters** : `?status=draft|ready|sent|acknowledged&data_stream_id=<uuid>`
**⚠️ Exception unique** : `attachments` array nested dans le show (avec UUIDs)

### Attachments (w pour POST/DELETE, r/w pour GET)

```http
POST   /api/v1/data_packages/:uuid/attachments  (w)      # 202 → {id: uuid, filename, processing_status: "pending", data_package_id: uuid, created_at}
GET    /api/v1/attachments/:uuid                         # show → {id: uuid, filename, processing_status, byte_size, virus_scan_result, encrypted, retry_count, data_package_id: uuid, created_at}
DELETE /api/v1/attachments/:uuid                 (w)      # 204
GET    /api/v1/attachments/:uuid/download                # 302 Redirect → S3 signed URL
GET    /api/v1/data_packages/:uuid/attachments/download  # Download all (ZIP)
POST   /api/v1/attachments/:uuid/retry          (w)      # Re-enqueue si status = scan_failed/encryption_failed/upload_failed
```

**Upload** : `multipart/form-data` + `file`, `filename`, `checksum: "sha256:abc..."`
**Processing states** : `pending → scanning → encrypting → uploading → completed` (ou `*_failed`)
**Note** : `id` exposé = UUID. `data_package_id` = UUID.

### Notifications (r/w)

```http
GET    /api/v1/notifications                        # index → [{id: uuid, data_package_id: uuid, subscription_id: uuid, organization_id: siret, status, sent_at, acknowledged_at, created_at}, ...]
GET    /api/v1/data_streams/:uuid/notifications     # index (filter par stream)
GET    /api/v1/notifications/:uuid                  # show  → {id: uuid, data_package_id: uuid, subscription_id: uuid, organization_id: siret, status, sent_at, acknowledged_at, created_at}
POST   /api/v1/notifications/:uuid/acknowledge      # {id: uuid, ...} (transitions: sent → acknowledged)
```

**Filters** : `?status=pending|sent|acknowledged&data_stream_id=<uuid>`
**Note** : `id` exposé = UUID. Relations : `data_package_id` = UUID, `organization_id` = SIRET.

### Users

```http
GET    /api/v1/users                         # index → [{id: uuid, email, name, created_at}, ...]
GET    /api/v1/users/:uuid                   # show  → {id: uuid, email, name, created_at}
GET    /api/v1/organizations/:siret/users    # index (users d'une org)
GET    /api/v1/users/:uuid/organizations     # index (orgs d'un user : [{id: siret, ...}]) - pas nested
POST   /api/v1/users                         # (admin futur)
PUT    /api/v1/users/:uuid                   # (admin futur)
DELETE /api/v1/users/:uuid                   # (admin futur)
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
- Organizations : SIRET exposé directement (pas d'`id`), identifiant naturel unique
- Autres ressources : UUID exposé comme `id` (colonne `uuid` auto-générée par `gen_random_uuid()`)
- Relations : Utiliser SIRET pour organizations, UUID pour autres

## Workflow Exemple : Producteur → Consommateur

```bash
# Producteur (SIRET: 11122233300001)
POST /api/v1/data_packages {data_stream_id: "<uuid>", title: "..."} → {id: "<uuid>", status: "draft"}
POST /api/v1/data_packages/<uuid>/attachments (multipart)           → {id: "<uuid>", processing_status: "pending"}
GET  /api/v1/attachments/<uuid> (polling)                           → {processing_status: "completed"}
POST /api/v1/data_packages/<uuid>/send                              → {id: "<uuid>", status: "sent"} + notifications créées

# Consommateur (SIRET: 98765432100034)
GET  /api/v1/notifications?status=sent                              → [{id: "<uuid>", data_package_id: "<uuid>", organization_siret: "98765432100034", ...}]
GET  /api/v1/data_packages/<uuid>                                   → {id: "<uuid>", sender_organization_siret: "11122233300001", attachments: [{id: "<uuid>", ...}]}
GET  /api/v1/attachments/<uuid>/download                            → 302 → S3 signed URL
POST /api/v1/notifications/<uuid>/acknowledge                       → {id: "<uuid>", status: "acknowledged"}
```
