# Hubee V2 - Documentation API REST

**Version**: 1.2.0
**Date**: 2025-01-27
**Base URL**: `/api/v1`

---

## Philosophie API

- **RESTful**: Ressources, verbes HTTP standards
- **Versioning**: `/api/v1/` (namespace)
- **Format**: JSON (Jbuilder templates)
- **Auth**: API Tokens (Bearer token)
- **Pagination**: Pagy (50 items/page par défaut)
- **Flat Responses**: Pas de nesting sauf attachments dans data_packages

## Authentification

### API Tokens (Bearer)

```http
Authorization: Bearer <token>
```

**Génération token** :
```ruby
organization = Organization.find_by(siret: '12345678900012')
token = organization.generate_api_token(name: 'Production API')
# Token retourné UNE SEULE FOIS (SHA256 stocké en DB)
```

**Validation** :
- Hash SHA256 du token
- Lookup en DB via `token_digest`
- Vérification expiration et révocation
- Update `last_used_at` pour audit

## Autorisations (r/w)

Les endpoints sont autorisés selon les droits de l'organisation sur le data_stream/data_package :
- **(r)** : Read - Organisation abonnée en lecture
- **(w)** : Write - Organisation abonnée en écriture ou propriétaire du stream
- **(r/w)** : Read ou Write

## Endpoints

### Organizations

```http
GET    /api/v1/organizations
GET    /api/v1/organizations/:id

# Admin (futur)
POST   /api/v1/organizations
PUT    /api/v1/organizations/:id
DELETE /api/v1/organizations/:id
```

**Response Structure** :
```json
{
  "organization": {
    "id": 1,
    "name": "DILA",
    "siret": "11122233300001",
    "created_at": "2024-01-15T10:00:00Z"
  }
}
```

### Data Streams

```http
GET    /api/v1/data_streams                    (r/w)
POST   /api/v1/data_streams                    (w)
GET    /api/v1/data_streams/:id                (r/w)
PUT    /api/v1/data_streams/:id                (w)
DELETE /api/v1/data_streams/:id               (w) - uniquement si aucune notification existante
```

**Response Structure** (flat, pas de nesting) :
```json
{
  "data_stream": {
    "id": 1,
    "name": "CertDC",
    "description": "Certificats de décès électroniques",
    "owner_organization_id": 5,
    "retention_days": 365,
    "created_at": "2024-01-10T10:00:00Z"
  }
}
```

**Create Example** :
```http
POST /api/v1/data_streams
Content-Type: application/json
Authorization: Bearer <token>

{
  "data_stream": {
    "name": "CertDC",
    "description": "Certificats de décès",
    "retention_days": 365
  }
}
```

### Subscriptions

```http
GET    /api/v1/organizations/:id/subscriptions
GET    /api/v1/data_streams/:id/subscriptions    (avec query params ?write=true&read=false)
GET    /api/v1/subscriptions/:id
POST   /api/v1/data_streams/:id/subscriptions
PUT    /api/v1/subscriptions/:id
DELETE /api/v1/subscriptions/:id
```

**Response Structure** (flat) :
```json
{
  "subscription": {
    "id": 1,
    "data_stream_id": 1,
    "organization_id": 10,
    "read": true,
    "write": false,
    "created_at": "2024-01-12T14:00:00Z"
  }
}
```

**Query Parameters** (GET /data_streams/:id/subscriptions) :
- `?write=true` : Filter par droit écriture
- `?read=false` : Filter par droit lecture

### Data Packages

```http
GET    /api/v1/data_packages                         (r/w)
POST   /api/v1/data_streams/:id/data_packages        (w) - passer array de subscriptions
GET    /api/v1/data_packages/:id                     (r/w)
PUT    /api/v1/data_packages/:id                     (w) - optionnel (changement nom uniquement)
DELETE /api/v1/data_packages/:id                     (w) - uniquement si aucune notification existante
POST   /api/v1/data_packages/:id/send                (w) - génère notifications pour abonnés

# Route spéciale pour listing par stream
GET    /api/v1/data_streams/:id/data_packages        (r/w)
```

**Note importante sur GET /data_streams/:id/data_packages** :
- **Producteur (w)** : Renvoie tous les data_packages du stream
- **Consommateur (r)** : Passe par les notifications (renvoie uniquement ceux notifiés à l'organisation)

**Response Structure** (exception : attachments nested) :
```json
{
  "data_package": {
    "id": 123,
    "data_stream_id": 1,
    "sender_organization_id": 5,
    "status": "draft",
    "title": "Certificat de décès M. Dupont",
    "sent_at": null,
    "created_at": "2024-01-15T10:30:00Z",
    "attachments": [
      {
        "id": 456,
        "filename": "certificat.pdf",
        "byte_size": 1048576,
        "processing_status": "completed",
        "created_at": "2024-01-15T10:35:00Z"
      }
    ]
  }
}
```

**Important** : Seul `attachments` est nested. Pas de `sender_organization`, `data_stream`, ou `notifications` nested.

**Query Parameters** :
- `?status=draft|ready|sent|acknowledged`
- `?data_stream_id=123`
- `?page=1&per_page=50`

**Create Example** :
```http
POST /api/v1/data_packages
Content-Type: application/json
Authorization: Bearer <token>

{
  "data_package": {
    "data_stream_id": 1,
    "title": "Certificat de décès M. Dupont",
    "target_sirets": ["12345678900012", "98765432100034"]
  }
}
```

**Send Package** :
```http
POST /api/v1/data_packages/123/send
Authorization: Bearer <token>

# Transitions status: ready → sent
# Crée notifications pour abonnés
```

### Attachments

```http
POST   /api/v1/data_packages/:id/attachments        (w)
GET    /api/v1/attachments/:id/download              (r/w)
DELETE /api/v1/attachments/:id                       (w)
GET    /api/v1/data_packages/:id/attachments/download
POST   /api/v1/attachments/:id/retry
```

**Upload Workflow** :
```http
POST /api/v1/data_packages/123/attachments
Content-Type: multipart/form-data
Authorization: Bearer <token>

file: <binary>
filename: "certificat.pdf"
checksum: "sha256:abc..."

# Response 202 Accepted
{
  "attachment": {
    "id": 456,
    "filename": "certificat.pdf",
    "processing_status": "pending",
    "data_package_id": 123
  }
}
```

**Check Status** :
```http
GET /api/v1/attachments/456
Authorization: Bearer <token>

# Response
{
  "attachment": {
    "id": 456,
    "filename": "certificat.pdf",
    "processing_status": "completed",
    "byte_size": 1048576,
    "virus_scan_result": "clean",
    "encrypted": true,
    "retry_count": 0,
    "created_at": "2024-01-15T10:35:00Z"
  }
}
```

**Download** :
```http
GET /api/v1/attachments/456/download
Authorization: Bearer <token>

# Response 302 Redirect vers S3 signed URL
# Ou 200 avec streaming si implémenté
```

**Retry Failed** :
```http
POST /api/v1/attachments/456/retry
Authorization: Bearer <token>

# Re-enqueue job si status = scan_failed, encryption_failed, upload_failed
```

### Notifications

```http
GET    /api/v1/notifications                        (r/w)
GET    /api/v1/data_streams/:id/notifications       (r/w)
GET    /api/v1/notifications/:id                    (r/w)
POST   /api/v1/notifications/:id/acknowledge        (r/w)
```

**Response Structure** (flat) :
```json
{
  "notification": {
    "id": 789,
    "data_package_id": 123,
    "subscription_id": 45,
    "organization_id": 10,
    "status": "sent",
    "sent_at": "2024-01-15T11:00:00Z",
    "acknowledged_at": null,
    "created_at": "2024-01-15T10:45:00Z"
  }
}
```

**Query Parameters** :
- `?status=pending|sent|acknowledged`
- `?data_stream_id=123`
- `?page=1&per_page=50`

**Acknowledge** :
```http
POST /api/v1/notifications/789/acknowledge
Authorization: Bearer <token>

# Transitions status: sent → acknowledged
```

### Users

```http
GET    /api/v1/users
GET    /api/v1/users/:id                            (nester ses orgas dedans?)
GET    /api/v1/organizations/:id/users

# Admin (futur)
POST   /api/v1/users
PUT    /api/v1/users/:id
DELETE /api/v1/users/:id
```

**Response Structure** (flat) :
```json
{
  "user": {
    "id": 1,
    "email": "user@example.gouv.fr",
    "name": "Marie Dupont",
    "created_at": "2024-01-10T10:00:00Z"
  }
}
```

**Question ouverte** : Faut-il nester les organizations dans GET /api/v1/users/:id ? À décider selon les besoins clients.

## Pagination

Toutes les listes utilisent Pagy :

```json
{
  "data_packages": [...],
  "meta": {
    "current_page": 1,
    "total_pages": 12,
    "total_count": 580,
    "per_page": 50
  }
}
```

**Query Parameters** :
- `?page=1` : Page number (défaut 1)
- `?per_page=50` : Items per page (défaut 50, max 100)

## Error Responses

### 401 Unauthorized
```json
{
  "error": "Unauthorized",
  "message": "Invalid or expired API token"
}
```

### 403 Forbidden
```json
{
  "error": "Forbidden",
  "message": "You are not authorized to perform this action"
}
```

### 404 Not Found
```json
{
  "error": "Not Found",
  "message": "Resource not found"
}
```

### 422 Unprocessable Entity
```json
{
  "error": "Unprocessable Entity",
  "errors": {
    "siret": ["must be 14 digits"],
    "name": ["can't be blank"]
  }
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal Server Error",
  "message": "An unexpected error occurred"
}
```

## Rate Limiting

Via Rack::Attack :

**Limites** :
- **Par IP** : 300 requêtes / 5 minutes
- **Par token** : 1000 requêtes / 1 heure

**Headers Response** :
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 950
X-RateLimit-Reset: 1642345678
```

**429 Too Many Requests** :
```json
{
  "error": "Too Many Requests",
  "message": "Rate limit exceeded. Retry after 120 seconds."
}
```

## Flat Responses Pattern

### Principe
Les réponses Jbuilder ne nestent PAS d'autres ressources complètes, sauf exception pour `attachments` dans `data_packages`.

### Exemples

**✅ Bon - Réponse plate** :
```ruby
# app/views/api/v1/data_streams/show.json.jbuilder
json.data_stream do
  json.extract! @data_stream, :id, :name, :description, :retention_days
  json.owner_organization_id @data_stream.owner_organization_id
  # Pas de json.owner_organization nested
end
```

**✅ Exception autorisée - Attachments** :
```ruby
# app/views/api/v1/data_packages/show.json.jbuilder
json.data_package do
  json.extract! @data_package, :id, :title, :status, :created_at

  # Exception : liste des attachments
  json.attachments @data_package.attachments do |attachment|
    json.extract! attachment, :id, :filename, :byte_size, :processing_status
  end
end
```

**❌ Mauvais - Nesting excessif** :
```ruby
# NE PAS FAIRE
json.data_stream do
  json.extract! @data_stream, :id, :name

  # ❌ Ne pas nester
  json.owner_organization do
    json.extract! @data_stream.owner_organization, :id, :name, :siret
  end

  # ❌ Ne pas nester
  json.subscriptions @data_stream.subscriptions do |sub|
    json.extract! sub, :id, :read, :write
  end
end
```

### Navigation Relations

Les clients font des requêtes séparées pour naviguer les relations :

```bash
# 1. Récupérer le data_package
GET /api/v1/data_packages/123
# Response contient data_stream_id, sender_organization_id

# 2. Si besoin du data_stream complet
GET /api/v1/data_streams/:stream_id

# 3. Si besoin de l'organization
GET /api/v1/organizations/:org_id

# 4. Si besoin des notifications
GET /api/v1/notifications?data_package_id=123
```

## Workflow Complet Exemple

### Création et Envoi d'un Paquet

```bash
# 1. Créer le paquet (status: draft)
POST /api/v1/data_packages
{
  "data_package": {
    "data_stream_id": 1,
    "title": "Certificat M. Dupont"
  }
}
# → Response: { "id": 123, "status": "draft" }

# 2. Uploader fichiers
POST /api/v1/data_packages/123/attachments
file: certificat.pdf
# → Response: { "id": 456, "processing_status": "pending" }

# 3. Attendre traitement complet (polling)
GET /api/v1/attachments/456
# → { "processing_status": "completed" }

# 4. Envoyer le paquet (status: ready → sent)
POST /api/v1/data_packages/123/send
# → Crée notifications pour abonnés

# 5. Abonné reçoit notification
GET /api/v1/notifications?status=sent
# → Liste des paquets disponibles

# 6. Abonné télécharge fichier
GET /api/v1/attachments/456/download
# → Redirect vers S3 signed URL

# 7. Abonné acquitte réception
POST /api/v1/notifications/789/acknowledge
```
