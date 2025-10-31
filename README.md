# Hubee V2

[![Ruby](https://img.shields.io/badge/Ruby-3.4.7-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.1.0-red.svg)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16+-blue.svg)](https://www.postgresql.org/)

Plateforme d'échange sécurisé de fichiers gouvernementaux (SecNumCloud, RGS niveau élevé).

## 📋 Prérequis

- Ruby 3.4.7
- PostgreSQL 18+
- Bundler 2.7+

## 🚀 Installation

### 1. Cloner le projet

```bash
git clone <repository-url>
cd hubee
```

### 2. Installer les dépendances

```bash
bundle install
```

### 3. Configurer la base de données

```bash
# Créer les bases de données (development + test)
bin/rails db:create

# Appliquer les migrations
bin/rails db:migrate
```

### 4. Lancer les tests

```bash
# RSpec (tests unitaires et request specs)
bundle exec rspec

# Cucumber (tests E2E)
bundle exec cucumber

# Tests avec couverture de code (minimum 80%)
COVERAGE=true bundle exec rspec
```

### 5. Lancer le serveur de développement

```bash
bin/rails server
```

L'application sera accessible sur http://localhost:3000

## 🧪 Tests

### RSpec

```bash
# Tous les tests
bundle exec rspec

# Tests spécifiques
bundle exec rspec spec/models/
bundle exec rspec spec/requests/
bundle exec rspec spec/interactors/
bundle exec rspec spec/policies/

# Avec couverture de code
COVERAGE=true bundle exec rspec
```

### Cucumber

```bash
# Tous les scénarios E2E
bundle exec cucumber

# Un scénario spécifique
bundle exec cucumber features/nom_feature.feature
```

## 🔍 Qualité du Code

### Linter (StandardRB)

```bash
# Vérifier le code
bundle exec standardrb

# Auto-corriger les violations
bundle exec standardrb --fix
```

### Sécurité (Brakeman)

```bash
# Scanner les vulnérabilités de sécurité
bin/brakeman --quiet
```

### Audit des dépendances

```bash
# Vérifier les vulnérabilités dans les gems
bundle audit check --update
```

## 🏗️ Architecture

- **Framework**: Rails 8.1.0
- **Base de données**: PostgreSQL 18+
- **Jobs asynchrones**: Solid Queue (PostgreSQL-based)
- **Stockage fichiers**: Active Storage + S3 compatible
- **Tests**: RSpec + Cucumber
- **Linting**: StandardRB
- **Autorisation**: Pundit
- **Authentification**: bcrypt (has_secure_password)

## 📚 Documentation

Pour plus d'informations, consulter :

- `.ai/context/OVERVIEW.md` - Vue d'ensemble du projet
- `.ai/context/ARCHITECTURE.md` - Architecture système détaillée
- `.ai/context/DATABASE.md` - Schéma base de données complet
- `.ai/context/TESTING.md` - Stratégie et exemples de tests
- `.ai/context/API.md` - Documentation API REST complète
- `.ai/context/DEVELOPMENT_WORKFLOW.md` - Workflow TDD feature par feature

## 🛠️ Commandes Utiles

```bash
# Base de données
bin/rails db:reset              # Drop + create + migrate + seed
bin/rails db:rollback           # Rollback dernière migration

# Console Rails
bin/rails console               # Console interactive

# Routes
bin/rails routes                # Afficher toutes les routes

# Jobs Solid Queue
bin/rails solid_queue:start     # Démarrer les workers
```

## 🧑‍💻 Développement

Le projet suit une approche **TDD feature par feature**. Consulter `.ai/context/DEVELOPMENT_WORKFLOW.md` pour le workflow détaillé.

### Ordre des Features

1. Feature 0: Setup (Rails, RSpec, Gems) ✅
2. Feature 1: Organizations
3. Feature 2: DataStreams
4. Feature 3: Subscriptions
5. Feature 4: DataPackages
6. Feature 5: Attachments (avec jobs async)
7. Feature 6: Notifications
8. Feature 7: Events (audit trail)
9. Feature 8: Jobs Retention
10. Feature 9: 🔐 Authentification (CRITIQUE avant déploiement)

## 🔐 Sécurité

- **Qualification**: SecNumCloud (ANSSI)
- **Conformité**: RGS niveau élevé
- **Chiffrement**: DS Proxy (DINUM)
- **Antivirus**: ClamAV
- **Audit**: Trail complet (1 an DB, 5 ans S3)

## 📊 Standards de Qualité

- ✅ Tous les tests passent (RSpec + Cucumber)
- ✅ StandardRB sans erreurs
- ✅ Brakeman sans warnings critiques
- ✅ Coverage ≥ 80%

## 📝 Licence

© 2025 DINUM - Tous droits réservés
