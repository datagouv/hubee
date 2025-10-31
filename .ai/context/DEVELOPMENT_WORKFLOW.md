# Hubee V2 - Workflow de Développement TDD

**Version**: 3.0.0
**Date**: 2025-01-27
**Approche**: Feature par Feature avec TDD

---

## Principe TDD Feature par Feature

**Règle** : Chaque feature est complète et testée avant de passer à la suivante.

```
Pour chaque feature :
  1. Model + Migration + Tests (RED → GREEN)
  2. Factory FactoryBot
  3. Interactors + Tests (si logique métier complexe)
  4. API Controller + Routes + Request Specs (RED → GREEN)
  5. Cucumber Feature pour workflow E2E
  6. CHECKPOINT → Feature déployable
  7. Git commit feature isolée
```

## Ordre Logique des Features

```
Features 0-8 : API complète (SANS authentification)
  ├─ 0. Setup          → Rails 8.1, RSpec, Gems
  ├─ 1. Organizations  → Model simple
  ├─ 2. DataStreams    → Flux de données
  ├─ 3. Subscriptions  → Abonnements
  ├─ 4. DataPackages   → Paquets avec états
  ├─ 5. Attachments    → Fichiers + async jobs
  ├─ 6. Notifications  → Envoi aux abonnés
  ├─ 7. Events         → Audit trail RGS
  └─ 8. Jobs Retention → Suppression automatique

Feature 9 : 🔐 AUTHENTIFICATION (CRITIQUE)
  └─ API Tokens + Pundit → Sécuriser TOUTE l'API

Feature 10 : Utilisateurs Web (futur)
  └─ Users has_secure_password → Interface admin future
```

## ⚠️ Point Critique : Feature 9 (Authentication)

**IMPORTANT** : Features 1-8 créent une **API OUVERTE** (développement uniquement).

**Feature 9 est OBLIGATOIRE** avant tout déploiement :
- Ajoute API Tokens (SHA256)
- Ajoute `before_action :authenticate_api!` partout
- Ajoute Pundit policies pour autorisation fine
- Ajoute Rate Limiting (Rack::Attack)

**Avant Feature 9** :
```bash
curl http://localhost:3000/api/v1/data_streams/1
# 200 OK (DANGEREUX - pas d'auth)
```

**Après Feature 9** :
```bash
curl http://localhost:3000/api/v1/data_streams/1
# 401 Unauthorized ✅

curl -H "Authorization: Bearer [TOKEN]" http://localhost:3000/api/v1/data_streams/1
# 200 OK (si autorisé) ✅
```

## Checkpoint Feature Complète

À la fin de chaque feature :
- [ ] Tous tests feature : **GREEN**
- [ ] Coverage feature : **>80%**
- [ ] Seeds mis à jour : **db/seeds.rb avec données réalistes**
- [ ] API endpoint : **Testé manuellement avec curl**
- [ ] Workflow E2E : **GREEN** (Cucumber si applicable)
- [ ] Git commit : **Feature isolée**
- [ ] **Feature déployable indépendamment**

## Cycle RED → GREEN → REFACTOR

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

## Commandes Essentielles

```bash
# Tests
bundle exec rspec                    # Tous tests
bundle exec rspec spec/models/       # Tests models uniquement
bundle exec cucumber                 # Tests E2E
COVERAGE=true bundle exec rspec      # Avec coverage

# Qualité
bundle exec standardrb               # Linting
bundle exec standardrb --fix         # Auto-correction
bin/brakeman --quiet                 # Security scan

# Database
bin/rails db:migrate                 # Apply migrations
bin/rails db:rollback                # Rollback last
bin/rails db:reset                   # Drop + create + migrate + seed
bin/rails db:seed                    # Reload seeds (idempotent)

# Jobs
bin/rails solid_queue:start          # Démarrer workers
bin/rails runner "ProcessAttachmentJob.perform_now(1)"  # Test job

# API Manual Testing
curl -X GET http://localhost:3000/api/v1/data_streams \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json"
```

## Documentation Complémentaire

### Avant de Commencer
- **Obligatoire** : Lire `docs/TECHNICAL_DESIGN.md`
- **Obligatoire** : Lire `docs/SOLUTIONS_CRITIQUES.md`
- **Recommandé** : Lire `.ai/context/OVERVIEW.md`

### Pendant le Développement
- `.ai/context/ARCHITECTURE.md` - Architecture système
- `.ai/context/DATABASE.md` - Schéma base de données
- `.ai/context/TESTING.md` - Stratégie de test
- `.ai/context/API.md` - Documentation API
- `.ai/context/lang-ruby/CODE-STYLE.md` - Conventions Ruby/Rails

### Workflow Détaillé par Feature
Consulter `docs/WORKFLOW_IMPLEMENTATION_TDD.md` pour le guide complet feature par feature.

## Solutions aux Problèmes Critiques

### 1. Capacité Workers
- **Base** : 10 workers (0.33 fichiers/sec)
- **Peak** : 20-30 workers (scaling manuel)
- **Monitoring** : Queue depth, temps attente

### 2. Gestion Mémoire
- **Limite** : 2GB par worker
- **Sémaphore** : Max 3 fichiers >100MB simultanés
- **GC** : Forcé après traitement fichiers lourds

### 3. États d'Erreur
- **Retry** : Automatique (max 3 tentatives)
- **États** : scan_failed, encryption_failed, upload_failed
- **Admin** : Interface pour retry manuel

### 4. API Polling
- **Pattern** : 202 Accepted → Poll GET /attachments/:id
- **Status** : pending → scanning → encrypting → uploading → completed

### 5. Database Cascade
- **RESTRICT** : Empêche suppression streams/subscriptions avec dépendances
- **CASCADE** : Supprime automatiquement attachments/notifications
- **Soft Delete** : deleted_at pour audit (90 jours avant hard delete)

### 6. API Tokens
- **Storage** : SHA256 hash (jamais en clair)
- **Expiration** : Configurable (défaut 1 an)
- **Révocation** : Immédiate
- **Audit** : last_used_at tracking

### 7. Rétention Fichiers
- **Job Quotidien** : 2h du matin (EnforceRetentionPolicyJob)
- **Warning** : Email 7 jours avant expiration
- **S3 Lifecycle** : Filet de sécurité

## Checklist Globale MVP

### Phase 0-8 : Développement API
- [ ] Setup complet (Rails 8.1, RSpec, Gems)
- [ ] Feature 1 : Organizations model
- [ ] Feature 2 : DataStreams
- [ ] Feature 3 : Subscriptions
- [ ] Feature 4 : DataPackages (soft delete)
- [ ] Feature 5 : Attachments (async processing)
- [ ] Feature 6 : Notifications
- [ ] Feature 7 : Events (audit trail)
- [ ] Feature 8 : Jobs récurrents (retention)
- [ ] **Coverage global >80%**

### Phase 9 : Sécurisation (CRITIQUE)
- [ ] ApiToken model + generate_api_token
- [ ] BaseController avec authenticate_api!
- [ ] Toutes les Pundit policies
- [ ] Tous les controllers mis à jour (authorize)
- [ ] Tous les tests mis à jour (API tokens)
- [ ] Rack::Attack configuré
- [ ] **Tests E2E avec auth : GREEN**

### Phase 10 : Users Web (Préparation)
- [ ] User model (has_secure_password)
- [ ] Seeds pour développement
- [ ] Compatible ProConnect OAuth (préparé)

### Déploiement
- [ ] Variables d'environnement configurées
- [ ] Database migrations appliquées
- [ ] Solid Queue configuré (workers)
- [ ] Monitoring actif
- [ ] **Feature 9 déployée et testée en staging**

## Standards de Qualité

### Règles Impératives
- ✅ Tous les tests passent (RSpec + Cucumber)
- ✅ StandardRB sans erreurs
- ✅ Brakeman sans warnings critiques
- ✅ Coverage ≥ 80%
- ✅ Seeds à jour et fonctionnels (`bin/rails db:seed`)

### ⚠️ Git & Commits - RÈGLES CRITIQUES

**IMPORTANT** : Ne JAMAIS committer directement sans validation utilisateur

1. **Workflow Obligatoire** :
   - ✅ Proposer les modifications (diff, résumé)
   - ✅ Attendre validation explicite de l'utilisateur
   - ✅ Committer UNIQUEMENT après accord
   - ❌ Ne JAMAIS faire `git commit` de manière autonome

2. **Exceptions** : Aucune
   - Même pour des corrections mineures
   - Même pour de la documentation
   - Même si demandé implicitement

3. **En cas de doute** : TOUJOURS demander confirmation avant commit

### Anti-Patterns à Éviter
- ❌ SQL brut sans sanitization (utiliser ActiveRecord)
- ❌ N+1 queries (utiliser includes/preload/eager_load)
- ❌ Secrets hardcodés (utiliser Rails credentials)
- ❌ Logique métier dans les vues (utiliser Interactors/helpers)
- ❌ Routes non-RESTful sans justification
- ❌ Nesting excessif dans l'API (flat responses sauf attachments)

### Conventions Code
- **Nommage** : Explicite et significatif
- **Early Returns** : Réduire la complexité
- **Service Objects** : Utiliser Interactors pour logique complexe
- **Background Jobs** : Pour traitements longs (>5s)
- **Gestion d'Erreurs** : rescue_from dans controllers
- **Routes RESTful** : Suivre conventions Rails
- **Validations** : Au niveau modèle + database constraints
- **Seeds** : Idempotents avec `find_or_create_by!`, données réalistes

## Durée Estimée Totale

**4-5 semaines** (180-220 heures) pour MVP complet et testé.

**Répartition** :
- Semaine 1 : Features 0-3 (Setup + Organizations + DataStreams + Subscriptions)
- Semaine 2 : Features 4-5 (DataPackages + Attachments avec jobs async)
- Semaine 3 : Features 6-8 (Notifications + Events + Jobs Retention)
- Semaine 4 : Feature 9 (Authentication + Authorization complète)
- Semaine 5 : Tests E2E, documentation, préparation déploiement

## Convention Seeds (db/seeds.rb)

**Principe** : Idempotents avec `find_or_create_by!`, données réalistes, nettoyage dev uniquement.

```ruby
if Rails.env.development?
  Organization.destroy_all
end

organizations_data = [
  {name: "DINUM", siret: "13002526500013"},
  {name: "ANSSI", siret: "13002802100010"}
]

organizations_data.each do |org_data|
  Organization.find_or_create_by!(siret: org_data[:siret]) do |org|
    org.name = org_data[:name]
  end
end
```

**Règles** : ✅ `find_or_create_by!` | ✅ Données réalistes | ✅ `if Rails.env.development?` | ❌ `create!` | ❌ `destroy_all` en prod

---

## Future Features & Améliorations

### Feature 11 : Validation SIRET Luhn (Post-MVP)

**Objectif** : Validation algorithmique SIRET (clé de Luhn) pour détecter erreurs de saisie

**MVP actuel** : Format uniquement (`/\A\d{14}\z/`)

**Implémentation** :
```ruby
# app/validators/siret_validator.rb
class SiretValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank? || value !~ /\A\d{14}\z/

    digits = value.chars.map(&:to_i)
    sum = digits.each_with_index.sum do |digit, index|
      if index.even?
        double = digit * 2
        double > 9 ? double - 9 : double
      else
        digit
      end
    end

    record.errors.add(attribute, "invalid checksum") unless (sum % 10).zero?
  end
end

# app/models/organization.rb
validates :siret, siret: true
```

**Bénéfices** : Détecte typos, améliore qualité données
**Tradeoff** : Complexité +tests
**Priorité** : 🟡 Medium | **Effort** : 4-6h | **Ref** : [Luhn Wikipedia](https://fr.wikipedia.org/wiki/Formule_de_Luhn)

---

### Autres Futures

- **Geocoding** : Adresse/coordonnées depuis API INSEE
- **Import Batch** : CSV/JSON en masse avec validation async
- **Cache Redis** : Organizations fréquentes
- **Soft Delete** : Audit trail avec `deleted_at`
