# Code Style - Hubee V2

> Règles de style et conventions de code pour le projet

## 🎯 Principes Généraux

- **StandardRB** pour le linting Ruby (zero-config)
- **Clarté > Concision** - Code lisible et maintenable
- **TDD obligatoire** - Tests avant implémentation
- **Early returns** - Réduire la complexité cognitive
- **Flat API responses** - Pattern sans nesting (sauf attachments)

## 🏗️ Architecture & Organisation

### Models (`app/models/*.rb`)

```ruby
class DataStream < ApplicationRecord
  # 1. Associations
  belongs_to :owner_organization, class_name: "Organization"

  # 2. Delegations (pour API claire)
  delegate :siret, to: :owner_organization, prefix: true

  # 3. Validations
  validates :name, presence: true
  validates :retention_days, numericality: {greater_than: 0}, allow_nil: true

  # ❌ Pas de logique métier complexe → utiliser Interactors
end
```

**Règles** :
- ✅ Validations complètes (presence, format, uniqueness, numericality)
- ✅ Associations explicites avec `class_name` si nécessaire
- ✅ `delegate` pour simplifier l'accès aux attributs d'associations
- ✅ Inverse associations : `has_many :data_streams, dependent: :restrict_with_error`
- ❌ Pas de logique métier → Interactors pour logique complexe
- ❌ Pas d'exposition d'IDs séquentiels

### Controllers (`app/controllers/api/v1/*_controller.rb`)

```ruby
class DataStreamsController < Api::BaseController
  # ✅ Utiliser find_by!(uuid:) ou find_by!(siret:)
  def show
    @data_stream = DataStream.find_by!(uuid: params[:uuid])
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
- ✅ `find_by!(uuid:)` ou `find_by!(siret:)`, jamais `find(params[:id])`
- ✅ `params.expect` au lieu de `require + permit`
- ✅ Erreurs : `@model.errors.messages` (hash flat, pas `.to_json`)
- ❌ Pas de logique métier → déléguer aux Interactors/Services
- ❌ Pas de `find(params[:id])` avec IDs séquentiels

### Views Jbuilder (`app/views/api/v1/*/*.json.jbuilder`)

```ruby
# ✅ Partials pour réutilisabilité
# _data_stream.json.jbuilder
json.id data_stream.uuid  # UUID comme "id"
json.extract! data_stream, :name, :description, :retention_days, :created_at
json.owner_organization_siret data_stream.owner_organization_siret  # delegate

# index.json.jbuilder
json.array! @data_streams, partial: "api/v1/data_streams/data_stream", as: :data_stream

# show.json.jbuilder
json.partial! "api/v1/data_streams/data_stream", data_stream: @data_stream
```

**Règles** :
- ✅ **Flat responses** : array direct pour index, objet direct pour show
- ✅ **Partials** : `_resource.json.jbuilder` pour DRY
- ✅ **Organizations** : `name, siret, created_at` (PAS d'`id`)
- ✅ **Autres ressources** : `id` (UUID), attributs, `created_at`
- ✅ **Relations** : utiliser `_siret` ou `_id` suffix, jamais nester l'objet complet
- ❌ **Exception unique** : `attachments` nested dans `data_packages` uniquement
- ❌ Pas d'exposition de `updated_at`, `id` séquentiel

### Routes (`config/routes.rb`)

```ruby
# ✅ param: :siret pour organizations
resources :organizations, param: :siret, only: [:index, :show]

# ✅ param: :uuid pour autres ressources
resources :data_streams, param: :uuid
```

**Règles** :
- ✅ `param: :siret` pour organizations (identifiant naturel)
- ✅ `param: :uuid` pour autres ressources
- ❌ Pas de `:id` par défaut

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

  describe "GET /api/v1/data_streams/:uuid" do
    subject(:make_request) { get api_v1_data_stream_path(uuid), headers: headers }

    context "when data_stream exists" do
      let(:data_stream) { create(:data_stream) }
      let(:uuid) { data_stream.uuid }

      before { make_request }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "returns flat JSON response" do
        expect(json).to have_key("id")
        expect(json["id"]).to eq(data_stream.uuid)
      end
    end

    context "when data_stream does not exist" do
      let(:uuid) { SecureRandom.uuid }

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

    create_table :data_streams do |t|
      t.string :name, null: false
      t.references :owner_organization, null: false,
                   foreign_key: {to_table: :organizations},
                   index: false  # ✅ Index manuel avec :concurrently
      t.uuid :uuid, default: -> { "gen_random_uuid()" }, null: false
      t.timestamps
    end

    # ✅ Indexes concurrents (production-safe)
    add_index :data_streams, :owner_organization_id, algorithm: :concurrently
    add_index :data_streams, :uuid, unique: true, algorithm: :concurrently
  end
end
```

**Règles** :
- ✅ `disable_ddl_transaction!` + `algorithm: :concurrently` pour indexes
- ✅ UUID : `default: -> { "gen_random_uuid()" }`
- ✅ Enable `pgcrypto` extension
- ✅ Foreign keys explicites
- ✅ Index sur colonnes queryées (owner_organization_id, uuid)
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
