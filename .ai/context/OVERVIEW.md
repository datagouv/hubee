# Hubee V2 - Vue d'Ensemble du Projet

**Version**: 1.2.0
**Date**: 2025-01-27
**Type**: Plateforme d'échange sécurisé de fichiers gouvernementaux

---

## Mission Produit

Hubee V2 permet à une organisation (administration centrale) de transmettre des fichiers à une ou plusieurs organisations habilitées via un système de flux récurrents ("data streams") auquel les organisations s'abonnent ("subscriptions").

## Acteurs

1. **Producteur de données**: Administration centrale émettrice
2. **Consommateur de données**: Administration/acteur public récepteur
3. **Hub (Hubee)**: Plateforme centrale d'échange

## Contraintes Principales

### Volumétrie
- **Fichiers/an**: ~10M fichiers/an (~27K/jour, ~0.3 fichier/seconde)
- **Taille Fichiers**: 10-500 Mo
- **Traitement Moyen**: ~30 secondes/fichier (scan + chiffrement + upload)

### Sécurité
- **Qualification**: SecNumCloud (ANSSI)
- **Données**: Sensibles, chiffrées au repos
- **Conformité**: RGS niveau élevé
- **Chiffrement**: DS Proxy (service DINUM)
- **Antivirus**: ClamAV (scan en mémoire)

### Architecture MVP
- **Workers Base**: 10 instances en production (0.33 fichiers/sec)
- **Auto-scaling**: Optionnel (passage manuel à 20-30 si pics)
- **Gestion Mémoire**: 2GB par worker, max 3 fichiers >100MB simultanés
- **États d'Erreur**: Retry automatique (max 3 tentatives)
- **Rétention**: Configurable par flux (défaut 365 jours)

## Objectifs MVP (12 mois)

- V2 en production
- 2 flux de proactivité intégrés
- 1 flux existant migré de V1 vers V2
- Séquence de flux chaînés opérationnelle

## Stack Technique

### Core
- **Framework**: Rails 8.1.0
- **Ruby**: 3.4.7
- **Database**: PostgreSQL 18.0
- **Jobs**: Solid Queue (PostgreSQL-based, pas de Redis)
- **Storage**: Active Storage + S3 compatible (Outscale/Scaleway)

### Patterns
- **Architecture**: MVC + Interactors (business logic)
- **Authorization**: Pundit (policies)
- **API Format**: JSON (Jbuilder templates)
- **Authentication**:
  - **API**: API Tokens (SHA256) pour organisations
  - **Web**: has_secure_password pour utilisateurs

### Testing & Quality
- **Framework**: RSpec + Cucumber
- **Specs**: Request specs pour API, Features pour workflows E2E
- **Coverage**: Cible 80%+
- **Linting**: StandardRB
- **Security**:
  - Brakeman (static analysis)
  - bundler-audit (gem vulnerabilities)
  - strong_migrations (safe database migrations)

## Concepts Métier Clés

### Data Stream (Flux de données)
Flux récurrent de transmission (ex: Certificats de décès "CertDC")
- Propriétaire: une organisation
- Rétention: configurable (défaut 365 jours)
- Abonnements: qui peut lire/écrire

### Subscription (Abonnement)
Lien entre une organisation et un flux
- Permissions: read/write
- Notifications: automatiques sur nouveaux paquets

### Data Package (Paquet de données)
Transmission d'un ensemble de fichiers
- États: draft → ready → sent → acknowledged
- Soft delete: pour audit trail (90 jours avant hard delete)
- Notifications: créées automatiquement pour abonnés

### Attachment (Fichier attaché)
Fichier individuel dans un paquet
- Pipeline: scan antivirus → chiffrement → upload S3
- États: pending → scanning → encrypting → uploading → completed
- Gestion erreurs: retry automatique (max 3), intervention admin possible

### Event (Audit)
Événement tracé pour conformité RGS
- Conservation: 1 an DB, 5 ans S3
- Format: JSON signé (HMAC SHA-256)
- Événements critiques: upload, scan, chiffrement, téléchargement, suppression

## Décisions Techniques MVP

### Simplifications
- ❌ **Pas de AASM**: Enum PostgreSQL + Interactors
- ❌ **Pas de Kubernetes HPA**: 10 workers fixes, scaling manuel
- ❌ **Pas de WebSocket**: Synchrone/asynchrone simple via jobs
- ❌ **Pas de Prometheus**: Logs Rails + monitoring S3 basique
- ✅ **Phase 2 Documentée**: Features avancées après validation MVP

### Visibilité API
- **Principe**: Seuls fichiers `completed` visibles via API consommateurs
- **Notifications**: Envoyées uniquement quand tous fichiers d'un paquet sont `completed`

### Sécurité Fichiers
**Workflow** (pas de bucket S3 temp):
1. Client upload → Rails (stockage RAM immédiat)
2. Job async récupère fichier depuis RAM
3. ClamAV scan en RAM (~10-15s)
4. DS Proxy encrypt en RAM (~15-20s)
5. Upload S3 Final (fichier chiffré uniquement)
6. GC.start (libération RAM)

**Conformité SecNumCloud**:
- ✅ Fichier clair JAMAIS persisté (ni disque, ni S3 temp)
- ✅ Fichier clair uniquement en RAM (~30s total)
- ✅ S3 Final contient uniquement fichiers chiffrés
- ✅ VPC privé (pas d'accès internet direct)
- ✅ Audit trail complet

## Structure Base de Données

### Tables Principales
- **organizations**: SIRET, API tokens
- **data_streams**: Flux avec rétention
- **subscriptions**: Abonnements (read/write)
- **data_packages**: Paquets avec soft delete
- **attachments**: Fichiers avec états processing
- **notifications**: Liens paquet → abonnés
- **events**: Audit trail RGS
- **api_tokens**: Authentification API (SHA256)

### Relations Clés
```
Organization (1) ─── (N) Subscriptions (N) ─── (1) DataStream
Organization (1) ─── (N) DataPackages
DataStream (1) ─── (N) DataPackages
DataPackage (1) ─── (N) Notifications (N) ─── (1) Subscription
DataPackage (1) ─── (N) Attachments
```

## Documentation Complémentaire

Toute la documentation est centralisée dans `.ai/context/` :

### Architecture & Design
- `.ai/context/ARCHITECTURE.md` - Architecture système détaillée
- `.ai/context/DATABASE.md` - Schéma base de données complet
- `.ai/context/API.md` - Documentation API REST complète

### Développement
- `.ai/context/DEVELOPMENT_WORKFLOW.md` - Workflow TDD feature par feature
- `.ai/context/CODE_STYLE.md` - Conventions Ruby/Rails et bonnes pratiques
- `.ai/context/TESTING.md` - Stratégie et exemples de tests

### Sécurité & Operations
- `.ai/context/SECURITY_CHECKS.md` - Outils de sécurité (bundler-audit, brakeman, strong_migrations)
- `.ai/context/git/GIT-WORKFLOW.md` - Workflow Git et conventions de commits

## Standards de Qualité

### Règles Impératives
- ✅ Tous les tests passent (RSpec + Cucumber)
- ✅ StandardRB sans erreurs
- ✅ Brakeman sans warnings critiques
- ✅ Coverage ≥ 80%

### Anti-Patterns à Éviter
- ❌ SQL brut sans sanitization
- ❌ N+1 queries (utiliser includes/preload/eager_load)
- ❌ Secrets hardcodés
- ❌ Logique métier dans les vues
- ❌ Routes non-RESTful sans justification
- ❌ **Nesting excessif dans l'API** : limiter au strict minimum (has_many jamais nestés)

## Conventions API REST

### Principe des Réponses API (Jbuilder)
**Règle**:
- ✅ **belongs_to** : nester l'objet complet (1 seul objet, évite requêtes multiples)
- ❌ **has_many** : jamais nester (risque explosion payload)
- Exception historique : `attachments` nested dans `data_packages` (has_many)

**Pattern Standard** :
```ruby
# ✅ Bon : belongs_to nesté
# GET /api/v1/data_streams/1
json.extract! @data_stream, :id, :name, :description, :retention_days
json.owner_organization do
  json.partial! "api/v1/organizations/organization", organization: @data_stream.owner_organization
end

# ✅ Bon : has_many = IDs seulement (pas nesté)
# GET /api/v1/notifications/1
json.extract! @notification, :id, :status, :sent_at, :acknowledged_at
json.data_package_id @notification.data_package_id
json.organization_id @notification.organization_id
```

**Exception Unique** (attachments dans data_packages) :
```ruby
# ✅ Exception autorisée : attachments listés dans data_package
# GET /api/v1/data_packages/1
json.data_package do
  json.extract! @data_package, :id, :title, :status, :created_at

  # Exception : on peut lister les attachments
  json.attachments @data_package.attachments do |attachment|
    json.extract! attachment, :id, :filename, :byte_size, :processing_status
    # Limite pratique : ~20-50 attachments par package
  end
end
```

**has_many à ne JAMAIS nester** :
```ruby
# ❌ Mauvais : Nester des has_many
json.data_stream do
  json.extract! @data_stream, :id, :name

  # ❌ Ne pas nester has_many
  # ❌ Ne pas nester has_many (subscriptions)
  json.subscriptions @data_stream.subscriptions do |sub|
    json.extract! sub, :id, :permission_type
  end
end

# ✅ Préférer : IDs uniquement pour has_many + endpoint séparé si nécessaire
json.data_stream do
  json.extract! @data_stream, :id, :name, :description
  # Client fait GET /api/v1/data_streams/:id/subscriptions si besoin
end
```

**Rationale** :
- Simplicité : Réponses prévisibles et consistantes
- Performance : Pas de N+1 queries accidentelles
- Cache : Facilite le cache des ressources individuelles
- Flexibilité : Client contrôle quelles relations charger
- Limite pagination : Évite d'inclure des listes potentiellement énormes

**Navigation Relations** :
Les clients doivent faire des requêtes séparées pour naviguer les relations :
```bash
# 1. Récupérer le data_package
GET /api/v1/data_packages/123

# 2. Si besoin du data_stream complet
GET /api/v1/data_streams/:stream_id
```
