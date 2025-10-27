# Hubee V2 - Stratégie de Test

**Version**: 1.2.0
**Date**: 2025-01-27
**Coverage Cible**: 80%+

---

## Philosophie TDD

### Cycle RED → GREEN → REFACTOR

```ruby
# 1. RED : Écrire test qui échoue
RSpec.describe Organization do
  it 'validates SIRET format' do
    org = build(:organization, siret: '123')
    expect(org).not_to be_valid
  end
end

# 2. GREEN : Implémenter minimum pour passer
class Organization < ApplicationRecord
  validates :siret, format: { with: /\A\d{14}\z/ }
end

# 3. REFACTOR : Améliorer sans casser
class Organization < ApplicationRecord
  SIRET_FORMAT = /\A\d{14}\z/

  validates :siret,
    format: { with: SIRET_FORMAT, message: 'must be 14 digits' }
end
```

## Architecture de Test

```
spec/
├── models/                 # Tests unitaires modèles
│   ├── organization_spec.rb
│   ├── data_stream_spec.rb
│   └── attachment_spec.rb
├── interactors/           # Tests logique métier
│   └── attachments/
│       ├── scan_virus_spec.rb
│       ├── encrypt_file_spec.rb
│       └── process_attachment_spec.rb
├── policies/              # Tests Pundit
│   ├── data_package_policy_spec.rb
│   └── attachment_policy_spec.rb
├── requests/              # Tests API (request specs)
│   └── api/
│       └── v1/
│           ├── data_packages_spec.rb
│           ├── notifications_spec.rb
│           ├── attachments_spec.rb
│           └── data_streams_spec.rb
└── support/
    ├── factory_bot.rb
    ├── request_helpers.rb
    └── shared_examples/

features/                  # Tests BDD Cucumber
├── api/
│   ├── data_package_creation.feature
│   ├── file_upload.feature
│   └── notification_workflow.feature
├── step_definitions/
│   ├── api_steps.rb
│   ├── organization_steps.rb
│   └── attachment_steps.rb
└── support/
    ├── env.rb
    └── database_cleaner.rb
```

## Request Specs (API Testing)

### Pattern avec let, before, context

```ruby
# spec/requests/api/v1/data_packages_spec.rb
require 'rails_helper'

RSpec.describe 'Api::V1::DataPackages', type: :request do
  # Lazy loading - créé uniquement si référencé
  let(:organization) { create(:organization) }
  let(:api_token) { organization.generate_api_token(name: 'Test Token') }
  let(:data_stream) { create(:data_stream, owner_organization: organization) }

  # Eager loading - créé avant chaque test
  let!(:subscription) do
    create(:subscription,
      organization: organization,
      data_stream: data_stream,
      write: true
    )
  end

  let(:headers) do
    {
      'Authorization' => "Bearer #{api_token}",
      'Content-Type' => 'application/json'
    }
  end

  describe 'POST /api/v1/data_packages' do
    let(:valid_params) do
      {
        data_package: {
          data_stream_id: data_stream.id,
          title: 'Certificat de décès',
          target_sirets: ['12345678900012']
        }
      }
    end

    context 'with valid API token' do
      before do
        post '/api/v1/data_packages',
          params: valid_params.to_json,
          headers: headers
      end

      it 'returns 201 Created' do
        expect(response).to have_http_status(:created)
      end

      it 'creates a data package' do
        expect(DataPackage.count).to eq(1)
      end

      it 'returns the created package' do
        json = JSON.parse(response.body)
        expect(json['data_package']['title']).to eq('Certificat de décès')
        expect(json['data_package']['status']).to eq('draft')
      end

      it 'creates notifications for target organizations' do
        expect(Notification.count).to eq(1)
      end
    end

    context 'without API token' do
      before do
        post '/api/v1/data_packages',
          params: valid_params.to_json,
          headers: { 'Content-Type' => 'application/json' }
      end

      it 'returns 401 Unauthorized' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          data_package: {
            data_stream_id: nil,
            title: ''
          }
        }
      end

      before do
        post '/api/v1/data_packages',
          params: invalid_params.to_json,
          headers: headers
      end

      it 'returns 422 Unprocessable Entity' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors' do
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'without write permission' do
      before do
        subscription.update!(write: false)
        post '/api/v1/data_packages',
          params: valid_params.to_json,
          headers: headers
      end

      it 'returns 403 Forbidden' do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/data_packages/:id' do
    let(:data_package) { create(:data_package, data_stream: data_stream) }

    context 'when package exists' do
      before do
        get "/api/v1/data_packages/#{data_package.id}", headers: headers
      end

      it 'returns 200 OK' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns package details' do
        json = JSON.parse(response.body)
        expect(json['data_package']['id']).to eq(data_package.id)
      end

      it 'includes only attachments, not other nested resources' do
        json = JSON.parse(response.body)
        expect(json['data_package']).to have_key('attachments')
        expect(json['data_package']).not_to have_key('sender_organization')
        expect(json['data_package']).to have_key('sender_organization_id')
      end
    end

    context 'when package does not exist' do
      before do
        get '/api/v1/data_packages/99999', headers: headers
      end

      it 'returns 404 Not Found' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
```

### Bonnes Pratiques Request Specs

1. **Utilisation de `let` et `let!`** :
   - `let` : Lazy loading, créé uniquement si utilisé
   - `let!` : Eager loading, créé systématiquement avant chaque test

2. **Organisation avec `context`** :
   - Grouper par conditions (token valide/invalide, paramètres valides/invalides)
   - Noms descriptifs commençant par "when" ou "with"

3. **Usage de `before`** :
   - Exécuter la requête HTTP une seule fois par context
   - Partagé par tous les `it` du même context

4. **Tests focalisés** :
   - Un `it` = une assertion principale
   - Tests séparés pour status code, body, side effects

## Cucumber Features (BDD)

### Exemple : Upload et traitement de fichier

```gherkin
# features/api/file_upload.feature
@api @file_upload
Feature: Upload et traitement de fichiers
  En tant qu'organisation productrice
  Je veux uploader des fichiers dans un data package
  Pour les transmettre aux consommateurs de manière sécurisée

  Background:
    Given une organisation "DILA" avec le SIRET "11122233300001"
    And un flux de données "CertDC" appartenant à "DILA"
    And une organisation "Commune Lyon" avec le SIRET "12345678900012"
    And "Commune Lyon" est abonnée en lecture au flux "CertDC"
    And un API token valide pour "DILA"

  Scenario: Upload réussi d'un fichier propre
    Given un data package en mode "draft" sur le flux "CertDC"
    When j'uploade un fichier "certificat.pdf" de 1 Mo
    Then la réponse API est "202 Accepted"
    And l'attachment a le status "pending"
    When le job de traitement s'exécute
    Then l'attachment passe par les états:
      | pending    |
      | scanning   |
      | encrypting |
      | uploading  |
      | completed  |
    And le fichier chiffré est présent sur S3
    And aucun fichier temporaire n'existe

  Scenario: Rejet d'un fichier infecté
    Given un data package en mode "draft" sur le flux "CertDC"
    When j'uploade un fichier infecté "malware.exe"
    Then la réponse API est "202 Accepted"
    When le job de traitement s'exécute
    Then l'attachment a le status "scan_failed"
    And l'erreur contient "Virus detected"
    And aucun fichier n'est présent sur S3

  Scenario: Retry automatique sur erreur de chiffrement
    Given un data package en mode "draft" sur le flux "CertDC"
    And le service DS Proxy est temporairement indisponible
    When j'uploade un fichier "document.pdf"
    And le job de traitement s'exécute
    Then l'attachment a le status "encryption_failed"
    And le compteur de retry est "1"
    When le service DS Proxy redevient disponible
    And le job de retry s'exécute
    Then l'attachment passe à "completed"
```

### Step Definitions

```ruby
# features/step_definitions/api_steps.rb
Given('une organisation {string} avec le SIRET {string}') do |name, siret|
  @organization = create(:organization, name: name, siret: siret)
end

Given('un API token valide pour {string}') do |org_name|
  organization = Organization.find_by(name: org_name)
  @api_token = organization.generate_api_token(name: 'Test Token')
  @headers = {
    'Authorization' => "Bearer #{@api_token}",
    'Content-Type' => 'application/json'
  }
end

When("j'uploade un fichier {string} de {int} Mo") do |filename, size_mb|
  file = fixture_file_upload(filename, 'application/pdf')

  post "/api/v1/data_packages/#{@data_package.id}/attachments",
    params: { file: file, filename: filename },
    headers: @headers
end

Then('la réponse API est {string}') do |expected_status|
  status_code = expected_status.split(' ').first.to_i
  expect(response.status).to eq(status_code)
end

Then('l\'attachment a le status {string}') do |status|
  @attachment = Attachment.last
  expect(@attachment.processing_status).to eq(status)
end
```

## Interactors Testing

```ruby
# spec/interactors/attachments/scan_virus_spec.rb
require 'rails_helper'

RSpec.describe Attachments::ScanVirus do
  describe '.call' do
    let(:file_content) { File.read(Rails.root.join('spec/fixtures/test.pdf')) }
    let(:context) { { file_content: file_content } }

    context 'when file is clean' do
      before do
        allow_any_instance_of(ClamAV::Scanner)
          .to receive(:scan_memory)
          .and_return(double(safe?: true))
      end

      it 'succeeds' do
        result = described_class.call(context)
        expect(result).to be_success
      end

      it 'sets virus_scan_result' do
        result = described_class.call(context)
        expect(result.virus_scan_result[:status]).to eq('clean')
      end
    end

    context 'when virus is detected' do
      before do
        allow_any_instance_of(ClamAV::Scanner)
          .to receive(:scan_memory)
          .and_return(double(safe?: false))
      end

      it 'fails' do
        result = described_class.call(context)
        expect(result).to be_failure
      end

      it 'sets error message' do
        result = described_class.call(context)
        expect(result.error).to eq('Virus detected in file')
      end
    end
  end
end
```

## Ordre d'Implémentation

1. **Models + Tests** : Modèles ActiveRecord avec validations
2. **Interactors + Tests** : Logique métier isolée et testable
3. **Policies + Tests** : Authorization Pundit
4. **Controllers + Request Specs** : API REST avec tests d'intégration
5. **Cucumber Features** : Tests end-to-end des workflows critiques

## Commandes de Test

```bash
# RSpec - Tests unitaires et request specs
bundle exec rspec
bundle exec rspec spec/models/
bundle exec rspec spec/interactors/
bundle exec rspec spec/requests/api/v1/

# Cucumber - Tests BDD end-to-end
bundle exec cucumber
bundle exec cucumber features/api/
bundle exec cucumber --tags @api

# Coverage
COVERAGE=true bundle exec rspec

# Tests complets
bundle exec rspec && bundle exec cucumber
```

## Checklist Avant Commit

- [ ] Tous les tests passent (`bundle exec rspec`)
- [ ] Cucumber features passent (`bundle exec cucumber`)
- [ ] StandardRB clean (`bundle exec standardrb`)
- [ ] Brakeman clean (`bin/brakeman --quiet`)
- [ ] Coverage ≥ 80% (`COVERAGE=true bundle exec rspec`)
- [ ] Pas de `binding.pry` ou `debugger` oublié
- [ ] N+1 queries éliminées (vérifier logs SQL)

## Standards de Test

### À Tester Systématiquement

**Models** :
- Validations (presence, format, uniqueness)
- Associations (belongs_to, has_many)
- Scopes (active, expired, etc.)
- Méthodes métier (status?, generate_token, etc.)

**Interactors** :
- Success path (happy path)
- Failure paths (erreurs prévisibles)
- Rollback si implémenté
- Side effects (DB, external APIs)

**Controllers/API** :
- Authentification (avec/sans token)
- Authorization (permissions Pundit)
- Status codes (200, 201, 401, 403, 404, 422)
- Format réponses JSON (structure Jbuilder)
- Validation erreurs

**Policies** :
- Tous les cas d'autorisation
- Permissions read/write
- Ownership checks

### À NE PAS Tester

- ❌ Rails internals (associations ActiveRecord par ex)
- ❌ Gems externes (interactor, pundit) sauf intégration
- ❌ Code trivial (getters/setters standards)

## Fixtures et Factories

### FactoryBot

```ruby
# spec/factories/organizations.rb
FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    sequence(:siret) { |n| "1234567890000#{n}".rjust(14, '0') }
  end
end

# spec/factories/data_packages.rb
FactoryBot.define do
  factory :data_package do
    association :data_stream
    association :sender_organization, factory: :organization
    title { 'Test Package' }
    status { 'draft' }

    trait :ready do
      status { 'ready' }
    end

    trait :with_attachments do
      after(:create) do |package|
        create_list(:attachment, 3, data_package: package, processing_status: 'completed')
      end
    end
  end
end
```

### Shared Examples

```ruby
# spec/support/shared_examples/api_authentication.rb
RSpec.shared_examples 'requires API authentication' do |method, path|
  context 'without API token' do
    it 'returns 401 Unauthorized' do
      send(method, path)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'with expired token' do
    let(:expired_token) do
      create(:api_token, expires_at: 1.day.ago)
    end

    it 'returns 401 Unauthorized' do
      send(method, path, headers: { 'Authorization' => "Bearer #{expired_token.token}" })
      expect(response).to have_http_status(:unauthorized)
    end
  end
end

# Usage
RSpec.describe 'Api::V1::DataPackages' do
  describe 'GET /api/v1/data_packages' do
    it_behaves_like 'requires API authentication', :get, '/api/v1/data_packages'
  end
end
```
