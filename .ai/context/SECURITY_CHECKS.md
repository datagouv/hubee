# Security Checks

Guide d'utilisation des outils de sécurité du projet.

## 📊 Environnement

- **PostgreSQL** : 18.0
- **Ruby** : 3.4.7
- **Rails** : 8.1.0

## 🔐 Outils Disponibles

### 1. bundler-audit
**Quoi** : Vérifie les vulnérabilités connues dans les gems
**Quand** : Avant chaque déploiement, après `bundle update`, dans CI

```bash
# Exécuter l'audit
bundle exec bundler-audit check

# Mettre à jour la base de données d'advisories
bundle exec bundler-audit update

# Via Rake task (recommandé)
rake security:bundler_audit
```

**Configuration** : `.bundler-audit.yml`

### 2. Brakeman
**Quoi** : Analyse statique du code Rails pour détecter les vulnérabilités
**Quand** : Avant chaque commit important, dans CI

```bash
# Exécuter Brakeman
bundle exec brakeman

# Mode silencieux (CI)
bundle exec brakeman --quiet

# Via Rake task (recommandé)
rake security:brakeman
```

### 3. strong_migrations
**Quoi** : Détecte les migrations dangereuses (downtime, perte de données)
**Quand** : Automatique lors de l'exécution des migrations

```bash
# Exécuter les migrations (strong_migrations vérifie automatiquement)
rails db:migrate
```

**Configuration** : `config/initializers/strong_migrations.rb`

## 🚀 Utilisation Rapide

### Tout Exécuter

```bash
# Lance bundler-audit + brakeman
rake security:all
# ou simplement
rake security
```

### Workflow Recommandé

**Avant un commit important** :
```bash
rake security
```

**Avant un déploiement** :
```bash
rake security
rails db:migrate:status  # Vérifier les migrations en attente
```

**Dans la CI** (à ajouter à `.github/workflows/` ou équivalent) :
```yaml
- name: Security checks
  run: |
    bundle exec bundler-audit update
    bundle exec bundler-audit check
    bundle exec brakeman --quiet --exit-on-warn
```

## 📋 Checklist Sécurité

### Avant Chaque Déploiement

- [ ] `bundle exec bundler-audit check` ✅
- [ ] `bundle exec brakeman` ✅
- [ ] Migrations testées en staging
- [ ] Variables d'environnement vérifiées
- [ ] Certificats SSL valides

### Après bundle update

- [ ] `bundle exec bundler-audit check`
- [ ] Tests de régression
- [ ] Vérifier les CHANGELOG des gems mises à jour

### Lors d'une Migration

- [ ] strong_migrations n'a pas détecté de problème
- [ ] Migration testée en staging avec données réelles
- [ ] Rollback testé
- [ ] Backup de la base avant migration en production

## 🔧 Ignorer un Advisory

**Uniquement si justifié** (ex: vulnérabilité non applicable à votre cas d'usage).

Éditer `.bundler-audit.yml` :

```yaml
ignore:
  - CVE-2024-12345  # Not applicable: nous n'utilisons pas la fonctionnalité vulnérable
```

**IMPORTANT** : Documenter la raison et prévoir une date de réexamen.

## 📚 Ressources

- [bundler-audit](https://github.com/rubysec/bundler-audit)
- [Brakeman](https://brakemanscanner.org/)
- [strong_migrations](https://github.com/ankane/strong_migrations)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
