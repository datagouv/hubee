# Hubee V2 - Schéma Base de Données

**Version**: 1.2.0
**Date**: 2025-01-27
**SGBD**: PostgreSQL 16+

---

## Schéma Complet

```sql
-- Organizations (SIRET) - Producteurs et Consommateurs
CREATE TABLE organizations (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR NOT NULL,
  siret VARCHAR(14) NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- API Tokens pour authentification M2M
CREATE TABLE api_tokens (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR NOT NULL,
  token_digest VARCHAR NOT NULL,
  last_used_at TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  revoked_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_api_tokens_digest ON api_tokens(token_digest);
CREATE INDEX idx_api_tokens_org ON api_tokens(organization_id);

-- Flux de données (ex: CertDC)
CREATE TABLE data_streams (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR NOT NULL,
  description TEXT,
  owner_organization_id BIGINT REFERENCES organizations(id),
  retention_days INTEGER DEFAULT 365,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Abonnements (qui peut lire/écrire un flux)
CREATE TABLE subscriptions (
  id BIGSERIAL PRIMARY KEY,
  data_stream_id BIGINT NOT NULL REFERENCES data_streams(id),
  organization_id BIGINT NOT NULL REFERENCES organizations(id),
  read BOOLEAN DEFAULT FALSE,
  write BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE(data_stream_id, organization_id)
);

-- Paquets de données (transmission d'un ensemble de fichiers)
CREATE TABLE data_packages (
  id BIGSERIAL PRIMARY KEY,
  data_stream_id BIGINT NOT NULL REFERENCES data_streams(id) ON DELETE RESTRICT,
  sender_organization_id BIGINT NOT NULL REFERENCES organizations(id),
  status VARCHAR NOT NULL DEFAULT 'draft',
  -- Status: draft → ready → sent → acknowledged
  title VARCHAR,
  sent_at TIMESTAMP,
  acknowledged_at TIMESTAMP,
  deleted_at TIMESTAMP, -- Soft delete (audit trail)
  deletion_reason TEXT, -- Ex: "Retention policy (365 days)"
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_data_packages_stream_status ON data_packages(data_stream_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_data_packages_sender_created ON data_packages(sender_organization_id, created_at) WHERE deleted_at IS NULL;

-- Notifications (liens data_package → subscriptions)
CREATE TABLE notifications (
  id BIGSERIAL PRIMARY KEY,
  data_package_id BIGINT NOT NULL REFERENCES data_packages(id) ON DELETE CASCADE,
  subscription_id BIGINT NOT NULL REFERENCES subscriptions(id) ON DELETE RESTRICT,
  organization_id BIGINT NOT NULL REFERENCES organizations(id),
  status VARCHAR NOT NULL DEFAULT 'pending',
  -- Status: pending → sent → acknowledged
  sent_at TIMESTAMP,
  acknowledged_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE(data_package_id, subscription_id)
);

CREATE INDEX idx_notifications_org_status ON notifications(organization_id, status);

-- Fichiers attachés (métadonnées)
CREATE TABLE attachments (
  id BIGSERIAL PRIMARY KEY,
  data_package_id BIGINT NOT NULL REFERENCES data_packages(id) ON DELETE CASCADE,
  filename VARCHAR NOT NULL,
  content_type VARCHAR,
  byte_size BIGINT,
  checksum_sha256 VARCHAR,
  processing_status VARCHAR NOT NULL DEFAULT 'pending',
  -- Status: pending, scanning, scan_failed, encrypting, encryption_failed, uploading, upload_failed, completed
  processing_error TEXT, -- Message d'erreur si échec
  retry_count INTEGER DEFAULT 0, -- Compteur retry (max 3)
  failed_at TIMESTAMP, -- Date du dernier échec
  virus_scan_result VARCHAR, -- 'pending', 'clean', 'infected'
  virus_scan_at TIMESTAMP,
  encrypted BOOLEAN DEFAULT FALSE,
  encrypted_at TIMESTAMP,
  encrypted_blob_key VARCHAR, -- S3 final (fichier chiffré uniquement, pas de bucket temp)
  deleted_at TIMESTAMP, -- Soft delete (audit trail)
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_attachments_processing_status ON attachments(processing_status) WHERE deleted_at IS NULL;
CREATE INDEX idx_attachments_package ON attachments(data_package_id) WHERE deleted_at IS NULL;

-- Événements audit (RGS)
CREATE TABLE events (
  id BIGSERIAL PRIMARY KEY,
  event_type VARCHAR(50) NOT NULL,
  auditable_type VARCHAR NOT NULL,
  auditable_id BIGINT NOT NULL,
  organization_id BIGINT NOT NULL REFERENCES organizations(id),
  ip_address INET,
  context JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL -- Pas de updated_at (immuable)
);

CREATE INDEX idx_events_auditable ON events(auditable_type, auditable_id);
CREATE INDEX idx_events_org_created ON events(organization_id, created_at);
CREATE INDEX idx_events_type ON events(event_type);

-- Users (interface web future)
CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT REFERENCES organizations(id),
  email VARCHAR NOT NULL UNIQUE,
  password_digest VARCHAR NOT NULL,
  role INTEGER DEFAULT 0, -- 0: user, 1: admin, 2: super_admin
  reset_password_token VARCHAR,
  reset_password_sent_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_reset_token ON users(reset_password_token);
```

## Stratégie Identifiants API

**Principe** : Ne jamais exposer les IDs séquentiels dans l'API (sécurité)

### Identifiants Naturels (ex: SIRET)
- Organizations : utiliser `siret` (14 chiffres, unique, immuable)
- Routes API : `/api/v1/organizations/:siret`
- Réponse JSON : `{id: "11122233300001", name: "...", siret: "11122233300001", ...}`

### Colonnes UUID Auto-générées
Pour les autres ressources, ajouter une colonne `uuid` :

```sql
-- Activer extension (une fois)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Exemple : data_streams
ALTER TABLE data_streams
  ADD COLUMN uuid UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE;

CREATE UNIQUE INDEX idx_data_streams_uuid ON data_streams(uuid);
```

**Migration Rails** :
```ruby
class AddUuidToDataStreams < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    add_column :data_streams, :uuid, :uuid, default: 'gen_random_uuid()', null: false
    add_index :data_streams, :uuid, unique: true
  end
end
```

**Ressources avec UUID** : data_streams, subscriptions, data_packages, attachments, notifications, users

**Référence** : [Rails PostgreSQL UUID Guide](https://guides.rubyonrails.org/active_record_postgresql.html#uuid)

## Relations Clés

```
Organization (1) ─┬─ (N) ApiTokens
                  ├─ (N) Users
                  ├─ (N) Subscriptions (N) ─── (1) DataStream
                  └─ (N) DataPackages (sender)

DataStream (1) ─┬─ (N) Subscriptions
                └─ (N) DataPackages

DataPackage (1) ─┬─ (N) Notifications (N) ─── (1) Subscription
                 └─ (N) Attachments

Notification (N) ─── (1) Organization (recipient)
```

## Comportements Cascade

### ON DELETE CASCADE
Suppression automatique des dépendances :
- `api_tokens` → `organizations` : Tokens supprimés avec organization
- `data_packages` → `attachments` : Fichiers supprimés avec paquet
- `data_packages` → `notifications` : Notifications supprimées avec paquet

### ON DELETE RESTRICT
Protection contre suppression :
- `data_streams` → `data_packages` : Ne peut supprimer stream avec paquets
- `subscriptions` → `notifications` : Ne peut supprimer subscription avec notifications

### Soft Delete
Champs `deleted_at` pour audit trail :
- `data_packages` : Conserve 90 jours avant hard delete
- `attachments` : Conserve 90 jours avant hard delete

**Job de cleanup** :
```ruby
# app/jobs/cleanup_soft_deleted_job.rb
# Hard delete après 90 jours pour conformité RGS + libération stockage
DataPackage.where('deleted_at < ?', 90.days.ago).find_each(&:destroy!)
```

## États des Machines

### Attachment Processing Status

```ruby
# app/models/attachment.rb
enum processing_status: {
  pending: 'pending',              # Upload initial
  scanning: 'scanning',            # Scan ClamAV en cours
  scan_failed: 'scan_failed',      # Virus détecté ou erreur scan
  encrypting: 'encrypting',        # Chiffrement DS Proxy en cours
  encryption_failed: 'encryption_failed', # Erreur chiffrement
  uploading: 'uploading',          # Upload S3 final en cours
  upload_failed: 'upload_failed',  # Erreur upload S3
  completed: 'completed'           # Traitement terminé avec succès
}
```

**Transitions valides** :
- `pending` → `scanning`
- `scanning` → `encrypting` | `scan_failed`
- `encrypting` → `uploading` | `encryption_failed`
- `uploading` → `completed` | `upload_failed`
- États d'échec → retry automatique (max 3, via `retry_count`)

### DataPackage Status

```ruby
# app/models/data_package.rb
enum status: {
  draft: 'draft',           # Création initiale, ajout fichiers
  ready: 'ready',           # Tous attachments completed
  sent: 'sent',             # Notifications envoyées aux abonnés
  acknowledged: 'acknowledged' # Tous consommateurs ont acquitté
}
```

### Notification Status

```ruby
# app/models/notification.rb
enum status: {
  pending: 'pending',       # Créée, paquet pas encore envoyé
  sent: 'sent',             # Paquet disponible pour téléchargement
  acknowledged: 'acknowledged' # Consommateur a confirmé réception
}
```

## Contraintes de Validation

### Organization
```ruby
validates :name, presence: true
validates :siret, presence: true, uniqueness: true,
  format: { with: /\A\d{14}\z/, message: 'must be 14 digits' }
```

### DataStream
```ruby
validates :name, presence: true
validates :owner_organization, presence: true
validates :retention_days, numericality: { greater_than: 0 }, allow_nil: true
```

### Subscription
```ruby
validates :data_stream, presence: true
validates :organization, presence: true
validates :data_stream_id, uniqueness: { scope: :organization_id }
validate :at_least_one_permission # read ou write doit être true
```

### DataPackage
```ruby
validates :data_stream, presence: true
validates :sender_organization, presence: true
validates :status, inclusion: { in: %w[draft ready sent acknowledged] }
validates :title, length: { maximum: 255 }
```

### Attachment
```ruby
validates :data_package, presence: true
validates :filename, presence: true
validates :byte_size, numericality: {
  greater_than: 0,
  less_than_or_equal_to: 524_288_000 # 500 MB
}
validates :processing_status, inclusion: {
  in: %w[pending scanning scan_failed encrypting encryption_failed uploading upload_failed completed]
}
```

### ApiToken
```ruby
validates :organization, presence: true
validates :name, presence: true
validates :token_digest, presence: true, uniqueness: true
validates :expires_at, presence: true

scope :active, -> {
  where(revoked_at: nil)
    .where('expires_at > ?', Time.current)
}
```

## Index Stratégiques

### Performance Queries

```sql
-- Recherche tokens actifs (authentification API)
CREATE INDEX idx_api_tokens_digest ON api_tokens(token_digest);

-- Liste data_packages par stream et statut (dashboards)
CREATE INDEX idx_data_packages_stream_status
  ON data_packages(data_stream_id, status)
  WHERE deleted_at IS NULL;

-- Liste notifications par organization (polling API)
CREATE INDEX idx_notifications_org_status
  ON notifications(organization_id, status);

-- Liste attachments en erreur (monitoring)
CREATE INDEX idx_attachments_processing_status
  ON attachments(processing_status)
  WHERE deleted_at IS NULL;

-- Audit trail lookup (compliance)
CREATE INDEX idx_events_org_created
  ON events(organization_id, created_at);
```

### Partial Index (Soft Delete)

Les index utilisent `WHERE deleted_at IS NULL` pour ignorer les enregistrements soft-deleted, améliorant les performances des requêtes courantes.

## Rétention et Archivage

### Rétention Fichiers (DataPackages)

```ruby
# Calculé par flux
expiration_date = data_package.created_at + data_stream.retention_days.days

# Job quotidien 2h du matin
EnforceRetentionPolicyJob.perform_later

# Soft delete après expiration
data_package.update!(
  deleted_at: Time.current,
  deletion_reason: "Retention policy (#{retention_days} days)"
)

# Hard delete après 90 jours
CleanupSoftDeletedJob.perform_later
```

### Audit Trail Events

```ruby
# Conservation DB : 1 an minimum (RGS)
Event.where('created_at < ?', 1.year.ago).delete_all

# Export S3 mensuel : 5 ans
# Format JSON signé HMAC SHA-256
ArchiveAuditEventsJob.perform_later
```

## Migrations Critiques

### Strong Migrations

Utilisation de `strong_migrations` gem pour éviter :
- ❌ Ajout colonne NOT NULL sans default (lock table)
- ❌ Changement type colonne (réindexation)
- ❌ Suppression colonne sans safety_assured
- ❌ Ajout index sans algorithm: :concurrently

**Exemple safe** :
```ruby
# Ajout colonne avec default safe
def change
  add_column :attachments, :retry_count, :integer, default: 0, null: false
end

# Index concurrent (pas de lock)
disable_ddl_transaction!
def change
  add_index :attachments, :processing_status, algorithm: :concurrently
end
```
