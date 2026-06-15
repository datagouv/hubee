# Hubee V2

[![Ruby](https://img.shields.io/badge/Ruby-4.0.5-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.1.0-red.svg)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18+-blue.svg)](https://www.postgresql.org/)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

Plateforme d'échange sécurisé de fichiers gouvernementaux (SecNumCloud, RGS niveau élevé).

## 📋 Prérequis

- Ruby 4.0.5
- PostgreSQL 18+ (requis pour `uuidv7()` natif — RFC 9562)
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

# Tests avec couverture de code (minimum 90%)
COVERAGE=true bundle exec rspec
```

### 5. Lancer le serveur de développement

```bash
bin/rails server
```

L'application sera accessible sur http://localhost:3000

## 🧪 Tests

### CI Locale Rails 8.1 (Recommandé)

```bash
# Exécute TOUS les checks en une seule commande
bin/ci
```

Cette commande exécute automatiquement :
- ✅ **Setup** : Préparation environnement
- ✅ **Style** : StandardRB (linting)
- ✅ **Security** : bundler-audit + brakeman + importmap
- ✅ **Database** : Préparation DB test
- ✅ **Tests** : RSpec (models + requests) + Cucumber (E2E)
- ✅ **Coverage** : Vérification >= 90%
- ✅ **Signoff** : Marque le commit comme approuvé (si tous checks passent)

**Durée** : ~10 secondes
**Même workflow** en local et sur GitHub Actions

#### Workflow avec GitHub Signoff

```bash
# 1. Commit vos changements
git add .
git commit -m "feat: nouvelle fonctionnalité"

# 2. Lancer la CI locale
bin/ci  # ✅ Si succès → commit marqué "approved"

# 3. Pusher (le status vert est déjà sur GitHub)
git push
```

**Prérequis** : `gh` CLI + extension `gh-signoff`

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

### Sécurité

```bash
# Tous les checks de sécurité (Brakeman + bundler-audit)
bundle exec rake security:all

# Scanner les vulnérabilités de sécurité (Brakeman)
bundle exec rake security:brakeman

# Audit des dépendances (bundler-audit)
bundle exec rake security:bundler_audit
```

## 🏗️ Architecture

- **Framework**: Rails 8.1.0
- **Base de données**: PostgreSQL 18+
- **Jobs asynchrones**: Solid Queue (PostgreSQL-based)
- **Stockage fichiers**: Active Storage + S3 compatible
- **Tests**: RSpec + Cucumber
- **Linting**: StandardRB
- **Sécurité**: strong_migrations, bundler-audit, Brakeman

## 🔒 Statut de l'API V2

L'ébauche d'API V2 présente dans ce repo (routes `api/v1`, 6 modèles, interactors de transmission) est **gelée**.

Le portail V2 (repo [`datagouv/hubee`](https://github.com/datagouv/hubee)) consomme l'API V1 via une gem cliente privée. La reprise du développement API V2 se fera ultérieurement, dans ce même repo.

> Les routes sont commentées dans `config/routes.rb` et les request specs exclues du run par défaut. Ne pas décommenter sans décision explicite de l'équipe.

## 📚 Documentation

Documentation de l'API V2 (gelée) :

- `docs/OVERVIEW.md` - Vue d'ensemble du projet
- `docs/ARCHITECTURE.md` - Architecture système détaillée
- `docs/DATABASE.md` - Schéma base de données complet
- `docs/API.md` - Documentation API REST complète

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

Le projet suit une approche **TDD feature par feature**.

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
- ✅ Coverage >= 90%

## 📦 Politique de versioning des gems

Les gems du projet ne portent **aucune contrainte de version** dans le `Gemfile`. Le `Gemfile.lock` joue son rôle : il fixe les versions exactes installées sur tous les environnements (dev, CI, prod). C'est lui le filet de sécurité, pas les contraintes de version.

Mettre à jour une gem se fait délibérément, via `bundle update <gem>`. Si la CI passe, la mise à jour est validée. Si elle casse, on le voit immédiatement et on décide d'adapter ou d'attendre.

Les contraintes de type `~> x.y` créent une fausse impression de contrôle : elles n'empêchent ni les bugs ni les breaking changes à l'intérieur d'une plage, mais elles bloquent les mises à jour majeures sans raison explicite et alourdissent la maintenance. On préfère la confiance dans les tests à la prudence par configuration.

## 📝 Licence

Ce projet est distribué sous licence **GNU Affero General Public License v3.0 (AGPL-3.0)**.

### Principales caractéristiques :

- ✅ **Liberté de modification** : Vous pouvez modifier et adapter le code
- ✅ **Liberté de distribution** : Vous pouvez redistribuer le code modifié ou non
- ⚠️ **Copyleft réseau** : Toute modification déployée sur un réseau (SaaS) doit être partagée
- 📄 **Code source** : Le code source complet doit être accessible aux utilisateurs

### Copyright

Copyright (C) 2025 DINUM (Direction Interministérielle du Numérique)

Pour plus d'informations, consultez le fichier [LICENSE](LICENSE) ou visitez https://www.gnu.org/licenses/agpl-3.0.html
