# Hubee V2 - Guide d'Onboarding Développeur

**Date de génération**: 25 novembre 2025
**Version codebase**: Rails 8.1 + Ruby 3.4.7 + PostgreSQL 18
**Auteur**: Documentation générée à partir du code réel

---

## Table des matières

1. [Vue d'ensemble du projet](#1-vue-densemble-du-projet)
2. [Stack technique](#2-stack-technique)
3. [Architecture métier](#3-architecture-métier)
4. [Ce qui a été implémenté](#4-ce-qui-a-été-implémenté)
5. [Patterns et choix techniques](#5-patterns-et-choix-techniques)
6. [Structure du code](#6-structure-du-code)
7. [Base de données](#7-base-de-données)
8. [API REST](#8-api-rest)
9. [Tests](#9-tests)
10. [Ce qui reste à faire](#10-ce-qui-reste-à-faire)
11. [Comment démarrer](#11-comment-démarrer)

---

## 1. Vue d'ensemble du projet

### Mission

**Hubee V2** est une plateforme d'échange sécurisé de fichiers entre administrations françaises. Elle permet à une organisation (administration centrale) de transmettre des fichiers à d'autres organisations habilitées via un système de **flux de données (data streams)** auxquels les organisations s'**abonnent (subscriptions)**.

### Acteurs

```
┌─────────────────────────────────────────────────────────────┐
│                      PRODUCTEUR                              │
│            (Ex: DINUM, ANSSI, Mairie de Lyon)               │
│                                                              │
│   → Crée des data_packages avec fichiers                    │
│   → Les transmet aux abonnés d'un flux                      │
└───────────────────────┬─────────────────────────────────────┘
                        │ API REST
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                      HUBEE V2                                │
│                   (Rails 8.1 API)                           │
│                                                              │
│   → Gère les flux (data_streams)                            │
│   → Gère les abonnements (subscriptions)                    │
│   → Stocke les fichiers chiffrés (S3)                       │
│   → Notifie les consommateurs                               │
└───────────────────────┬─────────────────────────────────────┘
                        │ API REST
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                    CONSOMMATEUR                              │
│         (Ex: CAF Paris, Pôle Emploi, CNAM)                  │
│                                                              │
│   → Reçoit des notifications                                │
│   → Télécharge les fichiers                                 │
│   → Acquitte la réception                                   │
└─────────────────────────────────────────────────────────────┘
```

### Contraintes clés

| Aspect | Contrainte |
|--------|------------|
| **Sécurité** | SecNumCloud (ANSSI), RGS niveau élevé |
| **Volumétrie** | ~10M fichiers/an (~27K/jour) |
| **Taille fichiers** | 10-500 Mo |
| **Chiffrement** | DS Proxy (service DINUM) |
| **Stockage** | S3 compatible (Outscale/Scaleway) |

---

## 2. Stack technique

### Backend

| Composant | Technologie | Pourquoi ce choix |
|-----------|-------------|-------------------|
| **Framework** | Rails 8.1.1 | Convention over configuration, productivité |
| **Ruby** | 3.4.7 | Performance YJIT, pattern matching |
| **Database** | PostgreSQL 18 | UUID v7 natif, JSONB, enums |
| **Jobs** | Solid Queue | Basé sur PostgreSQL, pas de Redis |
| **Storage** | Active Storage + S3 | Intégré Rails, compatible SecNumCloud |

### Gems principales (Gemfile)

```ruby
# Framework
gem "rails", "~> 8.1.1"

# API
gem "jbuilder"              # Vues JSON
gem "pagy", "~> 43.0"       # Pagination

# Business Logic
gem "aasm", "~> 5.5"        # State machine
gem "interactor", "~> 3.1"  # Organizers/Interactors
gem "pundit", "~> 2.4"      # Authorization (à implémenter)

# Security
gem "bcrypt"                # Passwords
gem "brakeman"              # Static analysis
gem "bundler-audit"         # Gem vulnerabilities
gem "strong_migrations"     # Safe migrations

# Testing
gem "rspec-rails"           # Tests
gem "factory_bot_rails"     # Factories
gem "cucumber-rails"        # BDD E2E
gem "shoulda-matchers"      # Matchers RSpec
```

---

## 3. Architecture métier

### Concepts clés

```
┌─────────────────────────────────────────────────────────────┐
│                     ORGANIZATION                             │
│   (SIRET: 13002526500013 - Ex: DINUM)                       │
│                                                              │
│   • Identifié par SIRET (14 chiffres)                       │
│   • Peut posséder des data_streams                          │
│   • Peut s'abonner à des data_streams                       │
│   • Peut envoyer des data_packages                          │
└─────────────────────────────────────────────────────────────┘
           │
           ├──────────────────────────────────────┐
           ▼                                      ▼
┌───────────────────────┐              ┌───────────────────────┐
│      DATA STREAM      │              │     SUBSCRIPTION      │
│   (Ex: "CertDC")      │◄────────────►│                       │
│                       │              │   • can_read: bool    │
│   • owner_organization│              │   • can_write: bool   │
│   • retention_days    │              │   • organization_id   │
│   • description       │              │                       │
└───────────────────────┘              └───────────────────────┘
           │
           ▼
┌───────────────────────┐              ┌───────────────────────┐
│     DATA PACKAGE      │─────────────►│     NOTIFICATION      │
│                       │              │                       │
│   • state: draft/     │              │   • subscription_id   │
│     transmitted/      │              │   • acknowledged_at   │
│     acknowledged      │              │                       │
│   • delivery_criteria │              └───────────────────────┘
│   • sender_organization│
│   • title             │
└───────────────────────┘
           │
           ▼
    ┌────────────┐
    │ ATTACHMENT │  (NON IMPLÉMENTÉ)
    │            │
    │ • filename │
    │ • status   │
    └────────────┘
```

### Workflow de transmission

```
1. CRÉATION (Producteur)
   ┌────────────────────────────────────────────────────────┐
   │  POST /api/v1/data_streams/:id/data_packages          │
   │  → DataPackage créé en state: "draft"                 │
   │  → delivery_criteria: {"siret": ["123...", "456..."]} │
   └────────────────────────────────────────────────────────┘
                              │
                              ▼
2. TRANSMISSION (Producteur)
   ┌────────────────────────────────────────────────────────┐
   │  POST /api/v1/data_packages/:id/transmission          │
   │  → Interactor DataPackages::Transmit s'exécute:       │
   │    1. ValidateTransmission (vérifie state=draft)      │
   │    2. ResolveRecipients (trouve subscriptions)        │
   │    3. CreateNotifications (crée notifications)        │
   │    4. TransitionToTransmitted (state=transmitted)     │
   └────────────────────────────────────────────────────────┘
                              │
                              ▼
3. RÉCEPTION (Consommateur)
   ┌────────────────────────────────────────────────────────┐
   │  GET /api/v1/notifications?status=sent                │
   │  → Liste les notifications en attente                 │
   │  GET /api/v1/data_packages/:id                        │
   │  → Récupère le contenu du paquet                      │
   │  POST /api/v1/notifications/:id/acknowledge           │
   │  → Acquitte la réception                              │
   └────────────────────────────────────────────────────────┘
```

---

## 4. Ce qui a été implémenté

### Features complètes (code existant)

| Feature | Status | Description |
|---------|--------|-------------|
| **Organizations** | ✅ Complet | CRUD + validation SIRET (14 chiffres) |
| **Data Streams** | ✅ Complet | CRUD + owner_organization + retention_days |
| **Subscriptions** | ✅ Complet | CRUD + permissions can_read/can_write |
| **Data Packages** | ✅ Complet | CRUD + state machine + delivery_criteria |
| **Notifications** | ✅ Complet | Création via transmission + acknowledge |
| **Transmission** | ✅ Complet | Interactor organizer complet |

### Features non implémentées (documentées dans .ai/context/)

| Feature | Status | Référence documentation |
|---------|--------|-------------------------|
| **Attachments** | ❌ Non codé | `.ai/context/ARCHITECTURE.md` - Section "Workflow Traitement Fichiers" |
| **API Tokens** | ❌ Non codé | `.ai/context/API.md` - Section "Authentification" |
| **Pundit Policies** | ❌ Non codé | `.ai/context/CODE_STYLE.md` - Section "Authorization" |
| **Events (Audit)** | ❌ Non codé | `.ai/context/DATABASE.md` - Table `events` |
| **Users** | ❌ Non codé | `.ai/context/DATABASE.md` - Table `users` |
| **Jobs Retention** | ❌ Non codé | `.ai/context/ARCHITECTURE.md` - Jobs récurrents |

---

## 5. Patterns et choix techniques

### 5.1 State Machine (AASM)

**Fichier**: `app/models/data_package.rb:17-31`

```ruby
aasm column: :state do
  state :draft, initial: true
  state :transmitted
  state :acknowledged

  event :send_package do
    transitions from: :draft, to: :transmitted
  end

  event :acknowledge do
    transitions from: :transmitted, to: :acknowledged
    after { update_column(:acknowledged_at, Time.current) }
    error { errors.add(:state, "must be transmitted") }
  end
end
```

**Choix technique**:
- Colonne `state` (pas `status`) pour précision technique
- États en anglais (`:transmitted` pas `:sent`) pour éviter conflits Ruby
- Enum PostgreSQL pour intégrité au niveau DB
- Timestamps séparés (`sent_at`, `acknowledged_at`)

### 5.2 Interactor Pattern (Organizer)

**Fichier**: `app/interactors/data_packages/transmit.rb`

```ruby
module DataPackages
  class Transmit
    include Interactor::Organizer

    organize Transmit::ValidateTransmission,
      Transmit::ResolveRecipients,
      Transmit::CreateNotifications,
      Transmit::TransitionToTransmitted
  end
end
```

**Pourquoi ce pattern**:
- Sépare la logique métier complexe des controllers
- Chaque étape est testable indépendamment
- Rollback automatique si une étape échoue
- Controller reste simple (if/else sur result)

**Structure des interactors**:
```
app/interactors/
└── data_packages/
    └── transmit/
        ├── validate_transmission.rb    # Vérifie state=draft
        ├── resolve_recipients.rb       # Résout delivery_criteria → subscriptions
        ├── create_notifications.rb     # Crée les notifications (rollback possible)
        └── transition_to_transmitted.rb # Transition AASM
```

### 5.3 Delivery Criteria (V1 = SIRET only)

**Choix technique**: Simplification pour MVP

**Validateur** (`app/validators/delivery_criteria_validator.rb`):
```ruby
# V1: Supporte uniquement {"siret": ["123...", "456..."]}
# V2 futur: Ajoutera _or, _and, organization_id, subscription_id
validate_each(record, attribute, value)
  validate_criteria!(value)
  # - Must be hash with only "siret" key
  # - Max 100 SIRETs
  # - Each SIRET must be 14 digits
end
```

**Resolver** (`app/queries/delivery_criteria_resolver.rb`):
```ruby
def self.resolve(criteria, data_stream)
  sirets = Array(criteria&.dig("siret"))
  return Subscription.none if sirets.empty?

  org_ids = Organization.where(siret: sirets).pluck(:id)
  Subscription
    .where(data_stream: data_stream, organization_id: org_ids)
    .with_read_permission
end
```

### 5.4 API Responses (Jbuilder)

**Règle**: Flat responses + belongs_to nesté

```ruby
# ✅ belongs_to nesté (1 objet)
# app/views/api/v1/data_streams/_data_stream.json.jbuilder
json.extract! data_stream, :id, :name, :description, :retention_days
json.owner_organization do
  json.partial! "api/v1/organizations/organization", organization: data_stream.owner_organization
end

# ❌ has_many JAMAIS nesté
# Client fait GET /api/v1/data_streams/:id/subscriptions si besoin
```

### 5.5 Scopes conditionnels

**Fichier**: `app/models/subscription.rb:9-22`

```ruby
scope :by_data_stream, ->(id) { id.present? ? where(data_stream_id: id) : all }
scope :by_organization, ->(id) { id.present? ? where(organization_id: id) : all }
scope :by_can_read, ->(value) {
  return all if value.nil?
  where(can_read: ActiveModel::Type::Boolean.new.cast(value))
}
```

**Usage dans controller**:
```ruby
def index
  @pagy, @subscriptions = pagy(
    Subscription
      .by_data_stream(params[:data_stream_id])
      .by_organization(params[:organization_id])
      .by_can_read(params[:can_read])
      .includes(:data_stream, :organization)
  )
end
```

### 5.6 params.expect (Rails 8.1)

```ruby
# Nouvelle syntaxe Rails 8.1 (pas require + permit)
def data_package_params
  params.expect(data_package: [:data_stream_id, :sender_organization_id, :title, delivery_criteria: {}])
end
```

---

## 6. Structure du code

```
hubee/
├── app/
│   ├── controllers/
│   │   └── api/
│   │       ├── base_controller.rb           # Pagination, error handling
│   │       └── v1/
│   │           ├── organizations_controller.rb
│   │           ├── data_streams_controller.rb
│   │           ├── subscriptions_controller.rb
│   │           ├── data_packages_controller.rb
│   │           ├── transmissions_controller.rb
│   │           └── data_packages/
│   │               └── subscriptions_controller.rb
│   │
│   ├── models/
│   │   ├── organization.rb      # SIRET validation, associations
│   │   ├── data_stream.rb       # belongs_to owner, has_many packages
│   │   ├── subscription.rb      # can_read/can_write, scopes
│   │   ├── data_package.rb      # AASM state machine, delivery_criteria
│   │   └── notification.rb      # acknowledge!, acknowledged?
│   │
│   ├── interactors/
│   │   └── data_packages/
│   │       └── transmit/        # Organizer pattern
│   │           ├── validate_transmission.rb
│   │           ├── resolve_recipients.rb
│   │           ├── create_notifications.rb
│   │           └── transition_to_transmitted.rb
│   │
│   ├── validators/
│   │   └── delivery_criteria_validator.rb  # V1 SIRET-only
│   │
│   ├── queries/
│   │   └── delivery_criteria_resolver.rb   # SIRET → subscriptions
│   │
│   └── views/api/v1/
│       ├── organizations/
│       │   ├── _organization.json.jbuilder  # Partial réutilisable
│       │   ├── index.json.jbuilder
│       │   └── show.json.jbuilder
│       ├── data_streams/
│       ├── subscriptions/
│       └── data_packages/
│
├── config/
│   ├── routes.rb                # RESTful + nested resources
│   └── initializers/
│       └── pagy.rb              # Pagination config
│
├── db/
│   ├── schema.rb                # UUID v7, enums PostgreSQL
│   └── seeds.rb                 # Données réalistes (DINUM, ANSSI, etc.)
│
├── spec/
│   ├── models/                  # Validations, scopes, associations
│   ├── interactors/             # Success/failure paths
│   ├── requests/api/v1/         # Request specs (status, JSON, DB changes)
│   ├── validators/
│   ├── queries/
│   └── factories/               # FactoryBot
│
└── .ai/
    └── context/                 # Documentation technique
        ├── OVERVIEW.md
        ├── ARCHITECTURE.md
        ├── DATABASE.md
        ├── API.md
        ├── CODE_STYLE.md
        ├── TESTING.md
        └── DEVELOPMENT_WORKFLOW.md
```

---

## 7. Base de données

### Schema actuel (implémenté)

```sql
-- UUID v7 natif PostgreSQL 18 (time-sortable)
-- Enum PostgreSQL pour états

CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  name VARCHAR NOT NULL,
  siret VARCHAR(14) NOT NULL UNIQUE
);

CREATE TABLE data_streams (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  name VARCHAR NOT NULL,
  owner_organization_id UUID NOT NULL REFERENCES organizations(id),
  retention_days INTEGER DEFAULT 365,
  description TEXT
);

CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  data_stream_id UUID NOT NULL REFERENCES data_streams(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  can_read BOOLEAN NOT NULL DEFAULT TRUE,
  can_write BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE(data_stream_id, organization_id)
);

CREATE TABLE data_packages (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  data_stream_id UUID NOT NULL REFERENCES data_streams(id) ON DELETE RESTRICT,
  sender_organization_id UUID NOT NULL REFERENCES organizations(id),
  state data_package_state DEFAULT 'draft',  -- ENUM: draft/transmitted/acknowledged
  title VARCHAR,
  delivery_criteria JSONB,
  sent_at TIMESTAMP,
  acknowledged_at TIMESTAMP
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  data_package_id UUID NOT NULL REFERENCES data_packages(id) ON DELETE CASCADE,
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE RESTRICT,
  acknowledged_at TIMESTAMP,
  UNIQUE(data_package_id, subscription_id)
);
```

### Relations clés

```
Organization (1) ─┬─ (N) DataStreams (owner)
                  ├─ (N) Subscriptions (subscriber)
                  └─ (N) DataPackages (sender)

DataStream (1) ─┬─ (N) Subscriptions
                └─ (N) DataPackages

DataPackage (1) ─── (N) Notifications (N) ─── (1) Subscription
```

### Comportements DELETE

| Relation | Type | Effet |
|----------|------|-------|
| subscriptions → data_streams | CASCADE | Supprime subscriptions avec stream |
| subscriptions → organizations | CASCADE | Supprime subscriptions avec org |
| data_packages → data_streams | RESTRICT | Empêche suppression stream si packages |
| notifications → data_packages | CASCADE | Supprime notifications avec package |
| notifications → subscriptions | RESTRICT | Empêche suppression subscription si notifs |

---

## 8. API REST

### Routes actuelles

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :organizations, only: %i[index show] do
      resources :subscriptions, only: %i[index]
    end

    resources :data_streams do
      resources :subscriptions, only: %i[index create]
      resources :data_packages, only: %i[index create]
    end

    resources :subscriptions, only: %i[show update destroy]

    resources :data_packages, only: %i[index show destroy] do
      resource :transmission, only: %i[create]  # POST /data_packages/:id/transmission
      resources :subscriptions, only: %i[index]
    end
  end
end
```

### Endpoints principaux

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/v1/organizations` | Liste des organisations |
| GET | `/api/v1/organizations/:id` | Détail organisation |
| GET | `/api/v1/data_streams` | Liste des flux |
| POST | `/api/v1/data_streams` | Créer flux |
| GET | `/api/v1/data_streams/:id/subscriptions` | Subscriptions d'un flux |
| POST | `/api/v1/data_streams/:id/data_packages` | Créer data package |
| POST | `/api/v1/data_packages/:id/transmission` | **Transmettre package** |
| GET | `/api/v1/data_packages/:id/subscriptions` | Prévisualiser/voir destinataires |

### Pagination

```bash
# Query params
GET /api/v1/organizations?page=1&per_page=50

# Response headers
X-Page: 1
X-Per-Page: 50
X-Total: 150
X-Total-Pages: 3

# Body: array direct (pas de wrapper)
[{...}, {...}, {...}]
```

### Erreurs

```json
// 404 Not Found
{"error": "Not found"}

// 422 Unprocessable Entity (validation)
{"name": ["can't be blank"], "siret": ["must be 14 digits"]}

// 422 Unprocessable Entity (business logic)
{"state": ["must be draft"]}
```

---

## 9. Tests

### Structure

```
spec/
├── models/
│   ├── organization_spec.rb        # Validations SIRET
│   ├── data_stream_spec.rb         # Associations, validations
│   ├── subscription_spec.rb        # Permissions, scopes
│   ├── data_package_spec.rb        # AASM, delivery_criteria
│   └── notification_spec.rb        # acknowledge!, validations
│
├── interactors/
│   └── data_packages/
│       ├── transmit_spec.rb                    # Organizer complet
│       └── transmit/
│           ├── validate_transmission_spec.rb   # Vérifie draft
│           ├── resolve_recipients_spec.rb      # SIRET → subscriptions
│           ├── create_notifications_spec.rb    # Création + rollback
│           └── transition_to_transmitted_spec.rb
│
├── validators/
│   └── delivery_criteria_validator_spec.rb     # V1 SIRET validation
│
├── queries/
│   └── delivery_criteria_resolver_spec.rb      # Resolution logic
│
├── requests/api/v1/
│   ├── organizations_spec.rb
│   ├── data_streams_spec.rb
│   ├── subscriptions_spec.rb
│   ├── data_packages_spec.rb
│   ├── transmissions_spec.rb
│   └── data_packages/subscriptions_spec.rb
│
└── factories/
    ├── organizations.rb
    ├── data_streams.rb
    ├── subscriptions.rb
    ├── data_packages.rb
    └── notifications.rb
```

### Pattern Request Spec

```ruby
RSpec.describe "Api::V1::DataPackages", type: :request do
  let(:headers) { {"Accept" => "application/json", "Content-Type" => "application/json"} }
  let(:json) { JSON.parse(response.body) }

  describe "POST /api/v1/data_packages/:id/transmission" do
    subject(:make_request) { post api_v1_data_package_transmission_path(data_package), headers: headers }

    context "when package is draft with recipients" do
      let(:data_package) { create(:data_package, :draft, :with_delivery_criteria) }

      it "returns 200 OK" do
        make_request
        expect(response).to have_http_status(:ok)
      end

      it "transitions to transmitted" do
        make_request
        expect(data_package.reload).to be_transmitted
      end
    end
  end
end
```

### Commandes

```bash
# Tous les tests
bundle exec rspec

# Tests spécifiques
bundle exec rspec spec/models/
bundle exec rspec spec/interactors/

# Avec coverage
COVERAGE=true bundle exec rspec

# Linting
bundle exec standardrb
bundle exec standardrb --fix

# Security
bin/brakeman --quiet
```

---

## 10. Ce qui reste à faire

### Feature 5: Attachments (PRIORITAIRE)

**Objectif**: Ajouter les fichiers aux data_packages

**À implémenter**:
- Model `Attachment` avec state machine (pending → scanning → encrypting → uploading → completed)
- Jobs async pour scan antivirus + chiffrement
- Active Storage + S3
- Endpoints API upload/download

**Référence**: `.ai/context/ARCHITECTURE.md` section "Workflow Traitement Fichiers"

### Feature 9: Authentification (CRITIQUE avant prod)

**Objectif**: Sécuriser toute l'API

**À implémenter**:
- Model `ApiToken` (SHA256 hash, expiration, révocation)
- `before_action :authenticate_api!` dans `BaseController`
- Pundit policies pour chaque ressource
- Rate limiting (Rack::Attack)

**Référence**: `.ai/context/API.md` section "Authentification & Autorisations"

### Feature 7: Events (Audit trail)

**Objectif**: Conformité RGS

**À implémenter**:
- Model `Event` (event_type, auditable, context JSONB)
- Helper `Event.log(type, auditable:, context:)`
- Conservation 1 an DB, export S3 5 ans

### Feature 8: Jobs Retention

**Objectif**: Suppression automatique après expiration

**À implémenter**:
- `EnforceRetentionPolicyJob` (cron 2h)
- `NotifyUpcomingRetentionJob` (warning 7j avant)
- Configuration Solid Queue

### Delivery Criteria V2

**Objectif**: Étendre le ciblage

**À implémenter**:
- Opérateurs `_or`, `_and`
- Critères `organization_id`, `subscription_id`
- Validation profondeur max + compteur critères

---

## 11. Comment démarrer

### Installation

```bash
# Clone
git clone <repo>
cd hubee

# Ruby (avec rbenv ou asdf)
ruby --version  # 3.4.7

# Dependencies
bundle install

# Database
bin/rails db:create db:migrate db:seed

# Vérifier
bin/rails db:seed  # 10 orgs, 16 streams, 20 subscriptions, 12 packages
```

### Lancer le serveur

```bash
bin/rails server
# API accessible sur http://localhost:3000/api/v1/
```

### Tester l'API

```bash
# Liste des organisations
curl http://localhost:3000/api/v1/organizations | jq

# Créer un data_package
curl -X POST http://localhost:3000/api/v1/data_streams/<UUID>/data_packages \
  -H "Content-Type: application/json" \
  -d '{"data_package": {"sender_organization_id": "<UUID>", "delivery_criteria": {"siret": ["77566988100032"]}}}' | jq

# Transmettre
curl -X POST http://localhost:3000/api/v1/data_packages/<UUID>/transmission | jq
```

### Workflow de développement

1. **Lire la doc contexte** : `.ai/context/DEVELOPMENT_WORKFLOW.md`
2. **TDD obligatoire** : RED → GREEN → REFACTOR
3. **StandardRB** : `bundle exec standardrb --fix` avant commit
4. **Coverage** : Cible 80%+

### Fichiers clés à lire en premier

| Fichier | Contenu |
|---------|---------|
| `app/models/data_package.rb` | State machine, validations, delivery_criteria |
| `app/interactors/data_packages/transmit.rb` | Organizer pattern complet |
| `app/queries/delivery_criteria_resolver.rb` | Résolution SIRET → subscriptions |
| `spec/requests/api/v1/transmissions_spec.rb` | Tests du workflow transmission |
| `db/seeds.rb` | Données de test réalistes |

---

## Questions fréquentes

### Pourquoi UUID v7 et pas v4 ?

UUID v7 est **time-sortable** (horodaté), donc :
- Pas besoin de `implicit_order_column`
- Index B-tree optimal (pas de fragmentation)
- +49% performance inserts vs v4

### Pourquoi AASM et pas un simple enum ?

AASM apporte :
- Guards sur transitions (validations)
- Callbacks `after` et `error`
- Méthodes prédicats (`draft?`, `transmitted?`)
- Méthodes bang (`send_package!`)

### Pourquoi Interactors et pas Service Objects ?

Le pattern Interactor::Organizer offre :
- Rollback automatique en cas d'échec
- Chaînage clair des étapes
- Contexte partagé entre étapes
- Tests unitaires par étape

### Pourquoi delivery_criteria en V1 est limité à SIRET ?

Simplification MVP. Le validator et resolver sont prêts pour V2 (commentaires dans le code montrent la structure future).

---

**Document généré automatiquement à partir du code source le 25 novembre 2025**
