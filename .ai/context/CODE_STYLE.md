# Code Style - Hubee V2

> Règles de style et conventions de code pour le projet

## 🎯 Principes Généraux

- **StandardRB** pour le linting Ruby (zero-config)
- **Clarté > Concision** - Code lisible et maintenable
- **TDD obligatoire** - Tests avant implémentation
- **Early returns** - Réduire la complexité cognitive
- **Flat API responses** - Pattern sans nesting (sauf attachments)
- **Arrays de symboles** : Toujours utiliser `%i[]` (ex: `only: %i[index show]`, jamais `%w[]`)

## 🏗️ Architecture & Organisation

### Models (`app/models/*.rb`)

```ruby
class DataStream < ApplicationRecord
  # 1. Associations
  belongs_to :owner_organization, class_name: "Organization"

  # 2. Validations
  validates :name, presence: true
  validates :retention_days, numericality: {greater_than: 0}, allow_nil: true

  # ❌ Pas de logique métier complexe → utiliser Interactors
end
```

**Règles** :
- ✅ Validations complètes (presence, format, uniqueness, numericality)
- ✅ Associations explicites avec `class_name` si nécessaire
- ✅ UUID primary keys partout (pas de delegates uuid nécessaires)
- ✅ Inverse associations : `has_many :data_streams, dependent: :restrict_with_error`
- ❌ Pas de logique métier → Interactors pour logique complexe
- ❌ Pas d'exposition d'IDs séquentiels (UUIDs uniquement)

### Scopes pour Filtres API

```ruby
class Subscription < ApplicationRecord
  # ✅ Scopes conditionnels pour filtres API
  scope :by_data_stream, ->(id) { id.present? ? where(data_stream_id: id) : all }
  scope :by_organization, ->(id) { id.present? ? where(organization_id: id) : all }

  # ✅ Scope avec validation enum
  scope :with_permission_types, ->(types) {
    return all unless types.is_a?(String)

    valid_types = types.split(",").map(&:strip).select { |t| permission_types.key?(t) }
    valid_types.any? ? where(permission_type: valid_types) : none
  }
end
```

**Règles** :
- ✅ Scopes conditionnels retournent `all` si paramètre absent/nil
- ✅ Validation des enums côté model (valeurs partiellement invalides → filtre valides uniquement)
- ✅ Toutes valeurs invalides → retourne `none` (résultat vide)
- ✅ Support String CSV uniquement (`"read,write"`)
- ✅ Strip whitespace automatique pour CSV
- ✅ Tests unitaires dans model specs (pas seulement request specs)

**Usage dans controller** :
```ruby
def index
  @pagy, @subscriptions = pagy(
    Subscription
      .by_data_stream(params[:data_stream_id])
      .by_organization(params[:organization_id])
      .with_permission_types(params[:permission_type])
      .includes(:data_stream, :organization)
  )
end
```

**Avantages** :
- ✅ Controller ultra-simple (1 ligne)
- ✅ Scopes réutilisables (console, jobs, etc.)
- ✅ Logique métier dans le model
- ✅ Testable unitairement

### State Machines (AASM)

Utiliser AASM pour gérer les transitions d'états complexes et garantir l'intégrité des workflows.

```ruby
class DataPackage < ApplicationRecord
  include AASM

  # State machine avec guards et callbacks
  aasm column: :state do  # ✅ Colonne 'state' (pas 'status')
    state :draft, initial: true
    state :transmitted  # ✅ État technique (pas 'sent')
    state :acknowledged

    # Événement avec guard, callback after, et error callback
    event :send_package do
      transitions from: :draft, to: :transmitted, guard: :has_completed_attachments?
      after { update_column(:sent_at, Time.current) }  # ✅ Callback en dehors du bloc transitions
      error { errors.add(:state, "must be draft") }    # ✅ Capture exception, ajoute erreur, retourne false
    end

    event :acknowledge do
      transitions from: :transmitted, to: :acknowledged
      after { update_column(:acknowledged_at, Time.current) }
      error { errors.add(:state, "must be transmitted") }
    end
  end

  # Scopes avec AASM (Array intersection pour validation)
  scope :by_state, ->(states) {
    return all unless states.is_a?(String)
    requested = states.split(",").map(&:strip)
    valid = DataPackage.aasm.states.map(&:name).map(&:to_s)
    valid_states = requested & valid  # Array intersection
    valid_states.any? ? where(state: valid_states) : none
  }
  scope :by_status, ->(statuses) { by_state(statuses) }  # Alias pour API

  private

  def has_completed_attachments?
    # Guard logique
  end
end
```

**Règles** :
- ✅ Colonne `state` (pas `status`) pour précision technique
- ✅ États techniques (`:transmitted` pas `:sent`) pour éviter conflits Ruby
- ✅ Timestamps d'action (ex: `sent_at`) distincts des états
- ✅ Guards pour valider transitions (`may_*?` vérifie automatiquement)
- ✅ Callbacks `after` **en dehors** du bloc `transitions` (syntaxe directe)
- ✅ Callback `error` capture exception, ajoute erreur, et retourne `false`
- ✅ États exposés comme méthodes prédicats (`draft?`, `transmitted?`)
- ✅ Scopes : Array intersection `&` pour validation élégante
- ❌ Jamais de transitions manuelles (`update!(state:)` interdit)

**Pattern Callback `error` AASM** :

Le callback `error` capture les exceptions `AASM::InvalidTransition`, ajoute les erreurs au modèle, et fait retourner `false` au lieu de lever l'exception :

```ruby
# Model - Callback error
event :send_package do
  transitions from: :draft, to: :transmitted, guard: :has_completed_attachments?
  after { update_column(:sent_at, Time.current) }
  error { errors.add(:state, "must be draft") }  # ✅ Capture exception + retourne false
end

# Controller - Appel direct avec !
def create
  if @data_package.send_package!  # Retourne true/false (pas d'exception grâce à error callback)
    render "api/v1/data_packages/show", status: :ok
  else
    render json: @data_package.errors, status: :unprocessable_content
  end
end
```

**Avantages** :
- ✅ Logique d'erreur centralisée dans le modèle (callback AASM)
- ✅ Controller ultra-simple (if/else direct)
- ✅ Format d'erreur Rails standard (attribut → array)
- ✅ Pas besoin de `rescue` ou méthode wrapper
- ✅ `send_package!` retourne `false` au lieu de raise grâce au callback
- ✅ Erreur sur l'attribut concerné (`:state`) pas sur `:base`

**Routes Nested Resource pour Transitions** :
```ruby
# routes.rb
resources :data_packages, only: %i[index show destroy], param: :id do
  resource :transmission, only: %i[create]  # Singulier pour action unique
end

# app/controllers/api/v1/transmissions_controller.rb
class Api::V1::TransmissionsController < Api::BaseController
  before_action :set_data_package

  def create
    if @data_package.send_package!  # Retourne true/false grâce au callback error
      render "api/v1/data_packages/show", status: :ok
    else
      render json: @data_package.errors, status: :unprocessable_content
    end
  end

  private

  def set_data_package
    @data_package = DataPackage.find(params[:data_package_id])
  end
end
```

### Controllers (`app/controllers/api/v1/*_controller.rb`)

```ruby
class DataStreamsController < Api::BaseController
  # ✅ Utiliser find(params[:uuid]) pour UUID primary keys
  def show
    @data_stream = DataStream.find(params[:uuid])
  end

  # ✅ params.expect (Rails 8.1+)
  def data_stream_params
    params.expect(data_stream: [:name, :description, :retention_days])
  end

  # ✅ Erreurs validation : render json: @model.errors.messages
  def create
    @data_stream = DataStream.new(data_stream_params)
    if @data_stream.save
      render :show, status: :created
    else
      render json: @data_stream.errors.messages, status: :unprocessable_entity
    end
  end
end
```

**Règles** :
- ✅ Hérite de `Api::BaseController`
- ✅ `find(params[:uuid])` pour UUID primary keys (direct, pas de find_by!)
- ✅ `params.expect` au lieu de `require + permit`
- ✅ Erreurs : `@model.errors.messages` (hash flat, pas `.to_json`)
- ❌ Pas de logique métier → déléguer aux Interactors/Services
- ❌ Pas d'IDs séquentiels exposés (UUIDs uniquement)

### Views Jbuilder (`app/views/api/v1/*/*.json.jbuilder`)

```ruby
# ✅ Partials pour réutilisabilité
# _data_stream.json.jbuilder
json.id data_stream.id  # UUID primary key comme "id"
json.extract! data_stream, :name, :description, :retention_days, :created_at, :updated_at
json.owner_organization_id data_stream.owner_organization_id  # FK UUID

# index.json.jbuilder
json.array! @data_streams, partial: "api/v1/data_streams/data_stream", as: :data_stream

# show.json.jbuilder
json.partial! "api/v1/data_streams/data_stream", data_stream: @data_stream
```

**Règles** :
- ✅ **Flat responses** : array direct pour index, objet direct pour show
- ✅ **Partials** : `_resource.json.jbuilder` pour DRY
- ✅ **Toutes les ressources** : `id` (UUID), attributs métier (ex: `siret` pour Organizations), `created_at`, `updated_at`
- ✅ **Relations** : utiliser `_id` suffix (toujours UUIDs), jamais nester l'objet complet
- ❌ **Exception unique** : `attachments` nested dans `data_packages` uniquement
- ❌ Pas d'exposition d'IDs séquentiels

### Routes (`config/routes.rb`)

```ruby
# ✅ param: :id (convention REST standard)
resources :organizations, param: :id, only: [:index, :show]
resources :data_streams, param: :id
```

**Règles** :
- ✅ `param: :id` pour toutes les ressources (convention REST, UUID primary keys)
- ✅ Routes comme `/api/v1/organizations/:id` où `:id` est un UUID

## 🧪 Tests (RSpec)

### Structure

```ruby
RSpec.describe DataStream do
  # ✅ Named subject
  subject(:data_stream) { build(:data_stream) }

  # ✅ Groupement logique
  describe "associations" do
    it { is_expected.to belong_to(:owner_organization) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    context "when retention_days is zero" do
      it "rejects the value" do
        data_stream.retention_days = 0
        expect(data_stream).not_to be_valid
      end
    end
  end
end
```

### Request Specs

```ruby
RSpec.describe "Api::V1::DataStreams", type: :request do
  let(:headers) { {"Accept" => "application/json", "Content-Type" => "application/json"} }
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/data_streams/:id" do
    subject(:make_request) { get api_v1_data_stream_path(id), headers: headers }

    context "when data_stream exists" do
      let(:data_stream) { create(:data_stream) }
      let(:id) { data_stream.id }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns flat JSON response" do
        expect(json).to have_key("id")
        expect(json["id"]).to eq(data_stream.id)
      end
    end

    context "when data_stream does not exist" do
      let(:id) { SecureRandom.uuid }

      before { make_request }

      it "returns 404 Not Found" do
        expect(response).to have_http_status(:not_found)
      end

      it "returns error message" do
        expect(json["error"]).to eq("Not found")
      end
    end
  end
end
```

**Règles** :
- ✅ `subject(:make_request)` nommé pour clarté
- ✅ `let`, `let!`, `context`, `before` intelligemment
- ✅ Tests status codes, structure JSON, erreurs
- ✅ Tests cas d'erreur (404, 422)
- ✅ Vérifie pas d'`id` exposé pour organizations
- ⚠️ Edge cases (nil values, limites, etc.)
- ❌ Pas de tests des internals Rails

### Factories (`spec/factories/*.rb`)

```ruby
FactoryBot.define do
  factory :data_stream do
    sequence(:name) { |n| "Data Stream #{n}" }
    description { Faker::Lorem.sentence }
    retention_days { rand(30..365) }
    association :owner_organization, factory: :organization

    # ✅ Traits pour variations
    trait :with_short_retention do
      retention_days { 30 }
    end
  end
end
```

**Règles** :
- ✅ `sequence` pour identifiants uniques
- ✅ Traits pour variations
- ✅ Faker pour données réalistes
- ⚠️ Éviter valeurs hardcodées

## 🗄️ Base de Données

### Migrations

```ruby
class CreateDataStreams < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!  # ✅ Pour indexes concurrents

  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :data_streams, id: :uuid do |t|
      t.string :name, null: false
      t.references :owner_organization, type: :uuid, null: false,
                   foreign_key: {to_table: :organizations},
                   index: false  # ✅ Index manuel avec :concurrently
      t.integer :retention_days, default: 365
      t.timestamps
    end

    # ✅ Indexes concurrents (production-safe)
    add_index :data_streams, :owner_organization_id, algorithm: :concurrently
  end
end
```

**Règles** :
- ✅ `id: :uuid` dans `create_table` pour UUID primary key (gen_random_uuid automatique)
- ✅ `t.references` avec `type: :uuid` pour foreign keys UUID
- ✅ `disable_ddl_transaction!` + `algorithm: :concurrently` pour indexes
- ✅ `index: false` dans references, puis `add_index` manuel avec `:concurrently`
- ✅ `foreign_key: {to_table: :...}` ou `foreign_key: {on_delete: :cascade}` inline
- ✅ Enable `pgcrypto` extension
- ✅ `implicit_order_column = :created_at` dans ApplicationRecord pour UUID ordering
- ❌ Pas de `NOT NULL` sans default ou logique de backfill

### Seeds (`db/seeds.rb`)

```ruby
# ✅ Idempotent avec find_or_create_by!
Organization.find_or_create_by!(siret: "13002526500013") do |org|
  org.name = "DINUM"
end

# ✅ Nettoyage en dev uniquement
if Rails.env.development?
  DataStream.destroy_all
  Organization.destroy_all
end
```

**Règles** :
- ✅ Idempotent avec `find_or_create_by!`
- ✅ Données réalistes pour tests
- ✅ Nettoyage seulement en dev
- ❌ Pas de `create!` direct

## 🎨 Ruby Style

### Guard Clauses & Early Returns

```ruby
# ✅ Early returns
def process_data_stream(stream)
  return nil if stream.nil?
  return false unless stream.valid?

  # Happy path
  stream.process
end

# ❌ Éviter deep nesting
def process_data_stream(stream)
  if stream
    if stream.valid?
      stream.process
    end
  end
end
```

### Delegation

```ruby
# ✅ Delegate pour API claire
class DataStream < ApplicationRecord
  belongs_to :owner_organization
  delegate :siret, :name, to: :owner_organization, prefix: true
end

# Usage: data_stream.owner_organization_siret au lieu de data_stream.owner_organization.siret

# ✅ allow_nil pour associations optionnelles
class Order < ApplicationRecord
  belongs_to :coupon, optional: true
  delegate :code, to: :coupon, prefix: true, allow_nil: true
end
```

### Params (Rails 8.1+)

```ruby
# ✅ params.expect
def data_stream_params
  params.expect(data_stream: [:name, :description, :retention_days])
end

# ❌ Old way
def data_stream_params
  params.require(:data_stream).permit(:name, :description, :retention_days)
end
```

## 🏛️ Principes SOLID (Architecture)

**Pragmatisme** : Guide la conception, pas un dogme absolu.

### S - Single Responsibility
**Une classe = une raison de changer.** Models pour données, Interactors pour logique métier, Jobs pour async.

```ruby
# ❌ DataPackage avec trop de responsabilités
class DataPackage
  def send_notifications; end
  def encrypt_files; end
end

# ✅ Responsabilités séparées
class DataPackage < ApplicationRecord; end
class SendDataPackage; include Interactor; end
class EncryptAttachmentJob < ApplicationJob; end
```

### O - Open/Closed
**Ouvert à l'extension, fermé à la modification.** Extension par composition plutôt que `case type`.

```ruby
# ❌ Ajouter format = modifier classe
class Exporter
  def export(type)
    case type
    when :csv then generate_csv
    when :pdf then generate_pdf
    end
  end
end

# ✅ Extension sans modification
class CsvExporter; def export(data); end; end
class PdfExporter; def export(data); end; end
```

### L - Liskov Substitution
**Sous-classes remplaçables.** Si `Penguin < Bird`, alors `bird.fly` ne doit pas raise. Revoir hiérarchie si besoin.

```ruby
# ❌ Penguin viole contrat Bird
class Bird; def fly; end; end
class Penguin < Bird; def fly; raise "Can't fly!"; end; end

# ✅ Hiérarchie correcte
class Bird; def move; end; end
class FlyingBird < Bird; def move; fly; end; end
class Penguin < Bird; def move; swim; end; end
```

### D - Dependency Inversion
**Dépendre d'abstractions.** Injection de dépendances plutôt que couplage fort. Testable avec mocks.

```ruby
# ❌ Couplé à FileLogger
class ProcessAttachment
  def call; FileLogger.new.log("..."); end
end

# ✅ Injection de dépendance
class ProcessAttachment
  def initialize(logger: Rails.logger); @logger = logger; end
  def call; @logger.info("..."); end
end
```

---

## 🔒 Sécurité & Performance

### Sécurité Critique

**1. Mass Assignment**
```ruby
params.expect(data_package: [:name, :title])  # Bloque attributs non-whitelistés
```

**2. SQL Injection**
```ruby
where(email: params[:email])  # ✅ Safe
where("email = '#{params[:email]}'")  # ❌ Injection
```

**3. Authorization**
```ruby
authorize @resource  # Pundit vérifie droits AVANT accès
```

**4. Fichiers Sensibles**
```ruby
# Signed URLs avec expiration
rails_blob_url(attachment, expires_in: 1.hour, disposition: "attachment")

# Validation : content_type whitelist, size < 500MB
# Virus scan : job asynchrone avant stockage final
```

**5. Encryption**
```ruby
encrypts :ssn  # ActiveRecord::Encryption (Rails 7+)
encrypts :api_key, deterministic: true  # Permet where()
```

**6. Secrets**
```ruby
Rails.application.credentials.dig(:aws, :key)  # ✅
ENV['AWS_KEY']  # ✅
"AKIAIOSFODNN7"  # ❌ JAMAIS hardcoder
```

**7. Rate Limiting**
```ruby
Rack::Attack.throttle('api/ip', limit: 300, period: 5.minutes)
```

**8. Audit Trail**
```ruby
Event.log('file_downloaded', auditable: @attachment, organization: current_organization, context: {ip: request.remote_ip})
```

### Performance

- ⚡ **Indexes** sur foreign keys et colonnes queryées
- ⚡ **Éviter N+1** → utiliser `includes` ou `joins`
- ⚡ **Pagination** sur collections larges (Pagy)
- ⚡ **Concurrent indexes** en production (`algorithm: :concurrently`)
- ⚡ **HTTP Caching** : `fresh_when(@resource)` pour ETag/Last-Modified
- ⚡ **Fragment caching** : `json.cache! ['v1', @resource] do ... end` en Jbuilder

## 📚 Références

- **StandardRB** : `bundle exec standardrb --fix`
- **Tests** : `bundle exec rspec`
- **Docs** : Voir `.ai/context/API.md`, `TESTING.md`, `DATABASE.md`, `ARCHITECTURE.md`
