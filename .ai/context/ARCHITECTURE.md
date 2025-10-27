# Hubee V2 - Architecture Système

**Version**: 1.2.0
**Date**: 2025-01-27

---

## Architecture Globale

```
┌─────────────────────────────────────────────────────────────┐
│                      PRODUCTEUR SI                          │
│                   (Administration centrale)                  │
└────────────────────────┬────────────────────────────────────┘
                         │ API REST (API Tokens)
                         │
┌────────────────────────▼────────────────────────────────────┐
│                     HUBEE V2 (Rails 8.1)                    │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Web UI       │  │  API REST    │  │ Background   │     │
│  │ (Sessions)   │  │ (API Tokens) │  │ Jobs         │     │
│  │              │  │              │  │ (SolidQueue) │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                  │                  │              │
│  ┌──────▼──────────────────▼──────────────────▼───────┐    │
│  │          Rails Application Layer                    │    │
│  │  (Controllers, Interactors, Policies)              │    │
│  └──────┬──────────────────────────────────────┬───────┘    │
│         │                                       │            │
│  ┌──────▼───────┐                    ┌─────────▼────────┐  │
│  │ PostgreSQL   │                    │  Active Storage  │  │
│  │ (Metadata)   │                    │  (S3 Outscale)   │  │
│  └──────────────┘                    └──────────────────┘  │
│                                                              │
└────────────────────────┬────────────────────────────────────┘
                         │ API REST (Bearer API Token)
                         │
┌────────────────────────▼────────────────────────────────────┐
│                   CONSOMMATEUR SI                           │
│              (Collectivités, Organismes publics)            │
└─────────────────────────────────────────────────────────────┘
```

## Composants Principaux

### 1. Authentification Rails Native
- **Interface Web**: Sessions Rails + has_secure_password
- **API**: API Tokens persistés en base (SHA256)
- **Users**: Agents publics avec email/password
- **Organizations**: API access via tokens révocables

### 2. Application Rails
- **Framework**: Rails 8.1.0
- **Pattern**: MVC + Interactors (business logic)
- **Authorization**: Pundit (policies)
- **Templating**: ERB (UI), Jbuilder (API JSON)
- **Testing**: RSpec (request specs) + Cucumber (features)

### 3. Base de Données
- **SGBD**: PostgreSQL 16+
- **Usage**: Métadonnées, relations, audit, queue jobs
- **Extensions**: pg (connecteur), solid_queue (jobs)
- **Pas de Redis**: Solid Queue utilise PostgreSQL

### 4. Stockage Fichiers
- **Solution**: Active Storage + S3 compatible
- **Provider MVP**: Local (disk) pour développement
- **Provider Prod**: Outscale/Scaleway S3 (SecNumCloud)
- **Architecture**: Un seul bucket S3 Final (pas de bucket temp)
- **Chiffrement**: DS Proxy (fichiers chiffrés au repos)
- **Traitement**: Fichiers en RAM pendant scan/encrypt puis upload direct S3 Final

### 5. Jobs Asynchrones
- **Queue**: Solid Queue (PostgreSQL-based)
- **Usage**: Scan antivirus, chiffrement, purge, notifications
- **Workers**: 10 en production (configurable par environnement)
- **Jobs récurrents**: Configurés via Solid Queue (pas de cron externe)

### 6. Antivirus
- **Solution**: ClamAV
- **Intégration**: Via job asynchrone
- **Stratégie**: Scan en mémoire (RAM) avant chiffrement
- **Pas de persistence**: Fichier clair en RAM uniquement (~30s)

### 7. Chiffrement
- **Outil**: DS Proxy (service gouvernemental DINUM)
- **Méthode**: Chiffrement côté serveur après scan
- **Stockage**: Fichiers chiffrés uniquement en S3 final
- **Conformité**: SecNumCloud (ANSSI)

## Workflow Traitement Fichiers

### Diagramme de Séquence

```
Client      Rails       Job         ClamAV    DSProxy     S3 Final
  │           │           │            │          │          │
  │ POST      │           │            │          │          │
  │ (file)    │           │            │          │          │
  ├──────────>│           │            │          │          │
  │           │ Store RAM │            │          │          │
  │           │ Enqueue   │            │          │          │
  │           ├──────────>│            │          │          │
  │ 202       │           │            │          │          │
  │<──────────┤           │            │          │          │
  │           │           │ Scan RAM   │          │          │
  │           │           ├───────────>│          │          │
  │           │           │ Clean      │          │          │
  │           │           │<───────────┤          │          │
  │           │           │ Encrypt    │          │          │
  │           │           ├────────────────────>│          │
  │           │           │ Encrypted  │          │          │
  │           │           │<────────────────────┤          │
  │           │           │ Upload S3 Final     │          │
  │           │           ├─────────────────────────────>│
  │           │           │ Success             │          │
  │           │           │<─────────────────────────────┤
  │           │           │ Update DB (completed)        │
  │           │           │ GC.start            │          │
```

**Note importante** : Pas de S3 Temp - le fichier reste en RAM pendant tout le traitement puis est directement uploadé chiffré sur S3 Final.

### Architecture Interactor

```
ProcessAttachment (Organizer)
├── ScanVirus          → ClamAV scan en RAM
├── EncryptFile        → DS Proxy chiffrement
├── UploadToStorage    → Upload S3 final
└── UpdateAttachment   → Mise à jour état DB
```

### États Attachment

```
pending         → Upload initial
  ↓
scanning        → Scan antivirus en cours
  ├─ clean ────────→ encrypting
  └─ infected ─────→ scan_failed ─┐
                                   │
encrypting      → Chiffrement DS Proxy
  ├─ success ──────→ uploading    │
  └─ error ────────→ encryption_failed ─┐
                                         │
uploading       → Upload S3 final       │
  ├─ success ──────→ completed          │
  └─ error ────────→ upload_failed ─────┤
                                         │
[États d'échec] ←────────────────────────┘
  ├─ Retry automatique (max 3 tentatives)
  └─ Intervention admin si échec persistant
```

## Sécurité Architecture

### Workflow Sécurisé Fichiers

```
1. Client upload → Rails (stockage RAM immédiat)
2. Job async récupère fichier depuis RAM
3. ClamAV scan en mémoire (~10-15s)
4. DS Proxy encrypt en mémoire (~15-20s)
5. Upload S3 Final (fichier chiffré uniquement) (~5s)
6. GC.start (libération RAM)
```

**Pas de bucket S3 temporaire** : Toute la chaîne de traitement se fait en RAM puis upload direct sur S3 Final.

### Conformité SecNumCloud

- ✅ Fichier clair JAMAIS persisté (ni disque, ni S3 temp)
- ✅ Fichier clair uniquement en RAM (~30s total)
- ✅ S3 Final contient uniquement fichiers chiffrés (DS Proxy)
- ✅ Durée exposition minimale (~30s en RAM)
- ✅ VPC privé (pas d'accès internet direct)
- ✅ Audit trail complet (tous événements tracés)
- ✅ TLS 1.3 obligatoire (API + S3)

### Authentification Dual-Mode

**Interface Web** (futurs utilisateurs) :
```ruby
# Sessions Rails standard
User.authenticate(email, password) → session[:user_id]
# has_secure_password (bcrypt)
```

**API Machine-to-Machine** :
```ruby
# API Tokens Bearer
Authorization: Bearer <token>
# Validation : SHA256 hash → lookup DB → check expiration/revocation
# Update last_used_at pour audit
```

### Authorization (Pundit)

```ruby
# Politique par ressource
class DataPackagePolicy < ApplicationPolicy
  def show?
    # Organisation émettrice OU réceptrice
    organization.id == record.sender_organization_id ||
      record.notifications.exists?(organization: organization)
  end

  def add_attachment?
    # Seul émetteur en mode draft
    organization.id == record.sender_organization_id &&
      record.draft?
  end
end
```

## Scalabilité et Performance

### Gestion Mémoire

**Par Worker** :
- Limite : 2GB maximum
- Sémaphore : Max 3 fichiers >100MB simultanés
- Monitoring : Utilisation mémoire en temps réel
- GC forcé : Après chaque gros fichier

**Workers** :
- Base : 10 instances (0.33 fichiers/seconde)
- Peak : 20-30 instances (scaling manuel si besoin)
- Auto-scaling : Optionnel (non-MVP)

### Jobs Récurrents

**Configuration Solid Queue** :
```ruby
# config/initializers/solid_queue.rb
Rails.application.config.solid_queue.recurring_tasks = {
  enforce_retention: {
    class: "EnforceRetentionPolicyJob",
    schedule: "0 2 * * *"  # 2h du matin
  },
  notify_upcoming_retention: {
    class: "NotifyUpcomingRetentionJob",
    schedule: "0 9 * * *"  # 9h du matin
  }
}
```

**Pas de cron externe** : Solid Queue gère les tâches récurrentes via PostgreSQL.

### Rate Limiting

```ruby
# Rack::Attack
- API par IP : 300 req / 5 minutes
- API par token : 1000 req / 1 heure
```

## Monitoring et Observabilité

### Health Check

```ruby
# GET /up
Rails.application.config.solid_queue.health_check = {
  database: true,
  storage: true,
  queue: true
}
```

### Métriques Clés

- **API Latency**: P50, P95, P99 par endpoint
- **Throughput**: Requêtes/seconde, fichiers/seconde
- **Error Rate**: % erreurs 5xx
- **Job Queue**: Longueur queue, temps attente
- **Storage**: Utilisation S3, croissance volumétrie
- **Memory**: Par worker, alertes si >85%

### Audit Trail (RGS)

```ruby
# Table events
CRITICAL_EVENTS = {
  'file_uploaded'       => 'Upload fichier',
  'file_scan_passed'    => 'Scan antivirus OK',
  'file_scan_failed'    => 'Virus détecté',
  'file_encrypted'      => 'Chiffrement réussi',
  'file_downloaded'     => 'Téléchargement fichier',
  'package_sent'        => 'Envoi validé',
  'delivery_acknowledged' => 'Accusé réception',
  'access_denied'       => 'Tentative accès non autorisé'
}
```

**Conservation** :
- DB : 1 an minimum (RGS)
- S3 : 5 ans (export mensuel JSON signé HMAC SHA-256)

## Infrastructure Cible

### Développement Local
- PostgreSQL local
- Storage : Disk local (storage/)
- Jobs : SolidQueue en mode async

### Production
- **App** : 4+ instances Puma (auto-scaling optionnel)
- **DB** : PostgreSQL HA (4vCPU, 8GB RAM, réplicas)
- **Storage** : S3 SecNumCloud (Outscale/Scaleway)
- **Workers** : 10 instances SolidQueue (2GB RAM chacun)
- **Monitoring** : Sentry (erreurs) + logs centralisés

### Variables d'Environnement Critiques

```bash
DATABASE_URL=postgresql://...
S3_ACCESS_KEY=xxx
S3_SECRET_KEY=xxx
DS_PROXY_ENDPOINT=https://ds-proxy.internal.gouv.fr
DS_PROXY_API_KEY=xxx
SECRET_KEY_BASE=xxx
RAILS_ENV=production
```
