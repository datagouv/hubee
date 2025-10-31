# Hubee V2 - Tests (TDD)

**Version**: 1.3.0 | **Coverage**: 80%+

> **Voir aussi** : `.ai/context/CODE_STYLE.md` pour conventions Ruby/Rails, RSpec patterns, factories

## Principes de Simplification

### ❌ Éviter la Sur-Testification
- **Models** : Ne pas tester en doublon ce que `is_expected.to validate_*` teste déjà (sauf validations custom complexes)
- **Request** : Tester la réponse JSON complète avec `match`, pas chaque attribut individuellement
- **Erreurs** : Un seul cas d'erreur si le comportement est identique
- **Pagination** : Vérifier le respect de la config Pagy, pas les nombres bruts
- **Commentaires** : Pas de commentaires dans les tests (le code doit être auto-explicatif)

### ✅ Ce qu'il Faut Tester

**Par endpoint et par cas (succès/erreur)** :
1. **Statut HTTP**
2. **Réponse JSON complète** : utiliser `match` avec tous les attributs attendus
3. **Évolutions DB** : vérifier les changements (création, update, suppression)
4. **Erreurs** : vérifier la structure complète JSON des erreurs avec `match`
5. **Pagination** : headers conformes à config Pagy

## Architecture

```
spec/
├── models/          # Validations (shoulda-matchers), associations, méthodes métier
├── interactors/     # Logique métier (success/failure, rollback)
├── policies/        # Pundit (permissions)
├── requests/api/v1/ # API HTTP (statut, JSON complet, DB changes, pagination)
└── support/         # Factories, helpers

features/            # Cucumber (workflows E2E complexes)
```

## Model Specs - Pattern Simplifié

```ruby
RSpec.describe Organization, type: :model do
  describe 'validations' do
    subject { build(:organization) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:siret) }
    it { is_expected.to validate_uniqueness_of(:siret).case_insensitive }

    describe 'siret format' do
      it 'accepts valid 14-digit SIRET' do
        expect(build(:organization, siret: '12345678901234')).to be_valid
      end

      it 'rejects SIRET with less than 14 digits' do
        organization = build(:organization, siret: '123')
        expect(organization).not_to be_valid
        expect(organization.errors[:siret]).to include('must be 14 digits')
      end
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:data_streams) }
  end
end
```

## Request Specs - Pattern Simplifié

```ruby
RSpec.describe 'Api::V1::Organizations', type: :request do
  let(:headers) { {'Accept' => 'application/json'} }
  let(:json) { JSON.parse(response.body) }

  describe 'GET /api/v1/organizations' do
    subject(:make_request) { get api_v1_organizations_path, headers: headers }

    context 'success' do
      let!(:org1) { create(:organization, name: 'Org A', siret: '11111111111111') }
      let!(:org2) { create(:organization, name: 'Org B', siret: '22222222222222') }

      before { make_request }

      it 'returns 200 OK' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns all organizations' do
        expect(json).to match_array([
          hash_including('name' => 'Org A', 'siret' => '11111111111111', 'created_at' => anything, 'updated_at' => anything),
          hash_including('name' => 'Org B', 'siret' => '22222222222222', 'created_at' => anything, 'updated_at' => anything)
        ])
      end

      it 'includes pagination headers' do
        expect(response.headers['X-Page']).to eq('1')
        expect(response.headers['X-Per-Page']).to eq(Pagy::DEFAULT[:limit].to_s)
      end
    end

    context 'with many records' do
      let!(:organizations) { create_list(:organization, 60) }

      before { make_request }

      it 'respects default page size from Pagy config' do
        expect(json.size).to eq(Pagy::DEFAULT[:limit])
      end
    end
  end

  describe 'GET /api/v1/organizations/:siret' do
    subject(:make_request) { get api_v1_organization_path(siret), headers: headers }

    context 'success' do
      let(:organization) { create(:organization, name: 'DILA', siret: '12345678901234') }
      let(:siret) { organization.siret }

      before { make_request }

      it 'returns 200 OK' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns organization data' do
        expect(json).to match(
          'name' => 'DILA',
          'siret' => '12345678901234',
          'created_at' => anything,
          'updated_at' => anything
        )
      end
    end

    context 'not found' do
      let(:siret) { '99999999999999' }

      before { make_request }

      it 'returns 404 Not Found' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns error response' do
        expect(json).to match(
          'error' => 'Not found'
        )
      end
    end
  end

  describe 'POST /api/v1/data_streams' do
    subject(:make_request) { post api_v1_data_streams_path, headers: headers, params: params.to_json }

    let(:organization) { create(:organization, siret: '13002526500013') }

    context 'success' do
      let(:params) { {data_stream: {name: 'CertDC', owner_organization_siret: organization.siret}} }

      it 'creates a new data_stream' do
        expect { make_request }.to change(DataStream, :count).by(1)
      end

      it 'returns 201 Created' do
        make_request
        expect(response).to have_http_status(:created)
      end

      it 'creates data_stream and returns complete data' do
        make_request
        created = DataStream.last
        expect(created).to have_attributes(name: 'CertDC')

        expect(json).to match(
          'id' => created.uuid,
          'name' => 'CertDC',
          'owner_organization_siret' => '13002526500013',
          'created_at' => anything,
          'updated_at' => anything
        )
      end
    end

    context 'validation error' do
      let(:params) { {data_stream: {owner_organization_siret: organization.siret}} }

      before { make_request }

      it 'does not create data_stream' do
        expect { make_request }.not_to change(DataStream, :count)
      end

      it 'returns 422 Unprocessable Content' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns validation errors' do
        expect(json).to match(
          'name' => array_including("can't be blank")
        )
      end
    end
  end

  describe 'DELETE /api/v1/organizations/:siret' do
    let!(:organization) { create(:organization) }
    subject(:make_request) { delete api_v1_organization_path(organization.siret), headers: headers }

    it { expect { make_request }.to change(Organization, :count).by(-1) }
    it { make_request; expect(response).to have_http_status(:no_content) }
  end
end
```

## Bonnes Pratiques RSpec

1. **`subject(:make_request)`** : Définir requête une fois (explicite recommandé)
2. **`let(:json)`** : Parser response.body centralisé (DRY)
3. **`let` vs `let!`** : lazy (si utilisé) vs eager (systématique)
4. **`context`** : Grouper par scénarios ("when organizations exist", "when not found")
5. **`before { make_request }`** : Exécuter requête UNE FOIS par context
6. **Tests focalisés** : 1 test = 1 assertion (status, body, attributs, errors séparés)
7. **Rails Scaffold** : Vérifier array direct (index), objet direct (show), pas de wrapper
8. **Errors** : Tester status + content-type + structure `{error, message}`

## Règles de Simplification

### Models
```ruby
# ✅ BON
it { is_expected.to validate_presence_of(:name) }
it 'validates format' do
  expect(build(:org, siret: 'invalid')).not_to be_valid
end

# ❌ MAUVAIS (doublon)
it 'is invalid without name' do
  org = build(:org, name: nil)
  expect(org).not_to be_valid
  expect(org.errors[:name]).to include("can't be blank")
end
```

### Request - JSON Complet (Succès et Erreurs)
```ruby
# ✅ BON : Snapshot complet avec match
it 'returns organization' do
  expect(json).to match(
    'name' => 'DILA',
    'siret' => '12345678901234',
    'created_at' => anything
  )
end

# ✅ BON : Erreurs complètes
it 'returns validation errors' do
  expect(json).to match(
    'name' => array_including("can't be blank")
  )
end

# ❌ MAUVAIS : Attributs individuels
it { expect(json['name']).to eq('DILA') }
it { expect(json).to have_key('created_at') }

# ❌ MAUVAIS : Erreur partielle
it { expect(json).to have_key('error') }
```

### Request - Un Seul Cas d'Erreur
```ruby
# ✅ BON
context 'validation error' do
  let(:params) { {organization: {name: ''}} }

  before { make_request }

  it 'returns 422 Unprocessable Content' do
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'returns validation errors' do
    expect(json).to match('name' => array_including("can't be blank"))
  end
end

# ❌ MAUVAIS : Multiples contexts pour même comportement
context 'missing name' { ... }
context 'missing siret' { ... }
context 'invalid siret format' { ... }
```

### Pagination - Config Pagy
```ruby
# ✅ BON
it 'respects Pagy default limit' do
  expect(json.size).to eq(Pagy::DEFAULT[:limit])
  expect(response.headers['X-Per-Page']).to eq(Pagy::DEFAULT[:limit].to_s)
end

# ❌ MAUVAIS (nombres hardcodés)
it 'returns 50 items' do
  expect(json.size).to eq(50)
  expect(response.headers['X-Per-Page']).to eq('50')
end
```

## Cycle TDD Simplifié

```ruby
# RED
it { expect { post_request }.to change(Organization, :count).by(1) }

# GREEN
def create
  @organization = Organization.create(params)
end

# REFACTOR
def create
  @organization = Organization.new(organization_params)
  @organization.save ? render(:show, status: :created) : render_errors
end
```

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
