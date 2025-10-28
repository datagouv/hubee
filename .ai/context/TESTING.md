# Hubee V2 - Tests (TDD)

**Version**: 1.2.0 | **Coverage**: 80%+

> **Voir aussi** : `.ai/context/CODE_STYLE.md` pour conventions Ruby/Rails, RSpec patterns, factories

## Cycle TDD

```ruby
# RED: Test échoue
it 'validates SIRET format' { expect(build(:organization, siret: '123')).not_to be_valid }

# GREEN: Implémentation minimale
validates :siret, format: { with: /\A\d{14}\z/ }

# REFACTOR: Amélioration
SIRET_FORMAT = /\A\d{14}\z/
validates :siret, format: { with: SIRET_FORMAT, message: 'must be 14 digits' }
```

## Architecture

```
spec/
├── models/          # Validations, associations, scopes, méthodes métier
├── interactors/     # Logique métier (success/failure paths, rollback, side effects)
├── policies/        # Pundit (read/write permissions, ownership)
├── requests/api/v1/ # API HTTP (auth, authorization, status codes, JSON format, errors)
└── support/         # Factories, shared examples, helpers

features/            # Cucumber BDD (workflows multi-endpoints complexes)
├── api/*.feature
├── step_definitions/
└── support/
```

## Request Specs - Pattern Complet

```ruby
RSpec.describe 'Api::V1::Organizations', type: :request do
  let(:headers) { {'Accept' => 'application/json', 'Content-Type' => 'application/json'} }
  let(:json) { JSON.parse(response.body) }  # DRY : parsing centralisé

  describe 'GET /api/v1/organizations' do
    subject(:make_request) { get api_v1_organizations_path, headers: headers }  # Subject nommé (recommandé)

    context 'when organizations exist' do
      let!(:org1) { create(:organization) }  # let! = eager loading
      let!(:org2) { create(:organization) }

      before { make_request }  # Requête exécutée UNE FOIS pour tous les tests

      it 'returns 200 OK' { expect(response).to have_http_status(:ok) }
      it 'returns JSON array (Rails scaffold)' { expect(json).to be_an(Array) }
      it 'returns all organizations' { expect(json.size).to eq(2) }
      it 'includes required attributes' { expect(json.first).to have_key('id') }
      it 'excludes updated_at' { expect(json.first).not_to have_key('updated_at') }
    end

    context 'when no organizations exist' do
      before { make_request }
      it 'returns empty array' { expect(json).to eq([]) }
    end
  end

  describe 'GET /api/v1/organizations/:id' do
    subject(:make_request) { get api_v1_organization_path(organization_id), headers: headers }

    context 'when organization exists' do
      let(:organization) { create(:organization, name: 'DILA') }  # let = lazy loading
      let(:organization_id) { organization.id }

      before { make_request }

      it 'returns 200 OK' { expect(response).to have_http_status(:ok) }
      it 'returns organization' { expect(json['id']).to eq(organization.id) }
      it 'does not nest (Rails scaffold)' { expect(json).not_to have_key('organization') }
    end

    context 'when organization does not exist' do
      let(:organization_id) { 999999 }
      before { make_request }

      it 'returns 404 Not Found' { expect(response).to have_http_status(:not_found) }
      it 'returns JSON error' { expect(json).to have_key('error') }
    end
  end
end
```

## Bonnes Pratiques

1. **`subject(:make_request)`** : Définir requête une fois (explicite recommandé)
2. **`let(:json)`** : Parser response.body centralisé (DRY)
3. **`let` vs `let!`** : lazy (si utilisé) vs eager (systématique)
4. **`context`** : Grouper par scénarios ("when organizations exist", "when not found")
5. **`before { make_request }`** : Exécuter requête UNE FOIS par context
6. **Tests focalisés** : 1 test = 1 assertion (status, body, attributs, errors séparés)
7. **Rails Scaffold** : Vérifier array direct (index), objet direct (show), pas de wrapper
8. **Errors** : Tester status + content-type + structure `{error, message}`

## Cucumber (BDD) - Workflows Complexes

```gherkin
# features/api/file_upload.feature
Feature: Upload et traitement de fichiers
  Background:
    Given une organisation "DILA" et un flux "CertDC"
    And "Commune Lyon" est abonnée en lecture
    And un API token valide pour "DILA"

  Scenario: Upload réussi
    Given un data package "draft"
    When j'uploade "certificat.pdf" de 1 Mo
    Then la réponse est "202 Accepted"
    And l'attachment passe par: pending → scanning → encrypting → uploading → completed
    And le fichier chiffré est sur S3

  Scenario: Fichier infecté rejeté
    When j'uploade un fichier infecté
    Then l'attachment a le status "scan_failed"
    And aucun fichier n'est sur S3

  Scenario: Retry automatique
    Given le service DS Proxy est indisponible
    When j'uploade "document.pdf"
    Then l'attachment a le status "encryption_failed"
    When le service redevient disponible et le job retry
    Then l'attachment passe à "completed"
```

**Step Definitions** :
```ruby
Given('une organisation {string} et un flux {string}') do |org, stream|
  @organization = create(:organization, name: org)
  @data_stream = create(:data_stream, name: stream, owner: @organization)
end
```

## Interactors

```ruby
RSpec.describe Attachments::ScanVirus do
  let(:context) { { file_content: File.read('spec/fixtures/test.pdf') } }

  context 'when file is clean' do
    before { allow_any_instance_of(ClamAV::Scanner).to receive(:scan_memory).and_return(double(safe?: true)) }

    it 'succeeds' { expect(described_class.call(context)).to be_success }
    it 'sets virus_scan_result' { expect(described_class.call(context).virus_scan_result[:status]).to eq('clean') }
  end

  context 'when virus is detected' do
    before { allow_any_instance_of(ClamAV::Scanner).to receive(:scan_memory).and_return(double(safe?: false)) }

    it 'fails' { expect(described_class.call(context)).to be_failure }
    it 'sets error' { expect(described_class.call(context).error).to eq('Virus detected in file') }
  end
end
```

## Ordre d'Implémentation TDD

1. Models + Tests (validations, associations, scopes)
2. Interactors + Tests (success/failure paths, rollback)
3. Policies + Tests (read/write, ownership)
4. Controllers + Request Specs (auth, status codes, JSON format)
5. Cucumber Features (workflows critiques end-to-end)

## Commandes

```bash
bundle exec rspec                              # Tous les tests
bundle exec rspec spec/models/                 # Models uniquement
bundle exec cucumber                           # BDD end-to-end
COVERAGE=true bundle exec rspec                # Avec coverage
bundle exec standardrb && bin/brakeman --quiet # Qualité code
```

## À Tester / Ne Pas Tester

**✅ À tester** :
- Models : validations, associations, scopes, méthodes métier
- Interactors : success/failure paths, rollback, side effects
- API : auth, authorization, status codes, JSON structure, errors
- Policies : read/write, ownership

**❌ Ne pas tester** : Rails internals, gems externes (sauf intégration), code trivial

## Factories & Shared Examples

```ruby
# Factories avec traits
FactoryBot.define do
  factory :data_package do
    association :data_stream
    title { 'Test Package' }
    status { 'draft' }

    trait :ready { status { 'ready' } }
    trait :with_attachments do
      after(:create) { |pkg| create_list(:attachment, 3, data_package: pkg, processing_status: 'completed') }
    end
  end
end

# Shared examples
RSpec.shared_examples 'requires API authentication' do |method, path|
  context 'without token' { it { send(method, path); expect(response).to have_http_status(:unauthorized) } }
end

# Usage
it_behaves_like 'requires API authentication', :get, '/api/v1/data_packages'
```
