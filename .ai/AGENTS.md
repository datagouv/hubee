# AI Configuration for hubee

> Central configuration file for all AI assistants working on this project

## 📁 Project Structure

This project uses a unified `.ai/` folder to configure all AI tools (Claude Code, Cursor, Windsurf, GitHub Copilot, etc.).

```
.ai/
├── AGENTS.md              # This file - main configuration
├── config.jsonc           # Configuration (committed, supports comments)
├── cli                    # Plugin manager CLI
├── context/               # Project knowledge and guidelines
│   ├── ARCHITECTURE.template.md  # System architecture (run .ai/cli migrate)
│   ├── OVERVIEW.template.md      # Project overview (run .ai/cli migrate)
│   ├── TESTING.template.md       # Testing strategy (run .ai/cli migrate)
│   ├── DATABASE.template.md      # Database schema (run .ai/cli migrate)
│   ├── GIT-WORKFLOW.md           # Git workflow (from git plugin)
│   └── <lang>/                   # Language-specific (from lang-* plugins)
├── commands/              # Custom slash commands (from plugins)
├── agents/                # Specialized agents (from plugins)
├── avatars/               # AI behavior profiles
└── scripts/               # Validation and utility scripts
```

**Note**: Language-specific contexts (node/, typescript/, etc.) are added via plugins.
Run `.ai/cli plugins add lang-node` to add Node.js context, for example.

## 🎯 How to Use This Configuration

### For AI Models

When working on this codebase, you should:

1. **Read this file first** - It contains the main project directives
2. **Check context folders** - Language/framework-specific guidelines are in `.ai/context/<language>/`
3. **Look for local documentation** - Each module may have:
   - `README.md` - Module overview and usage
   - `AGENTS.md` or `CLAUDE.md` - AI-specific directives for that module

**Example**: When working in a Node.js module:
- Read `.ai/context/node/` for Node.js best practices
- Check the module's `README.md` for module-specific context
- Check for `AGENTS.md` in the module folder for additional AI directives

## 📚 Context Organization

### Global Context

All cross-cutting concerns and project-wide guidelines should be documented in `.ai/context/` or this file.

### Module-Specific Context

For module or feature-specific directives, create an `AGENTS.md` (or `README.md`) in that module's folder:

```
src/
├── auth/
│   ├── AGENTS.md          # Authentication-specific AI directives
│   └── ...
└── billing/
    ├── AGENTS.md          # Billing-specific AI directives
    └── ...
```

## 🎯 Project Information

**Project**: Hubee V2
**Description**: Plateforme d'échange sécurisé de fichiers gouvernementaux (SecNumCloud, RGS niveau élevé)
**Tech Stack**: Rails 8.1 + Ruby 3.4.7 + PostgreSQL 18+ + Solid Queue + Active Storage (S3)

### Documentation Essentielle

**Vue d'Ensemble** :
- `.ai/context/OVERVIEW.md` - Mission, contraintes, concepts métier, conventions API

**Architecture** :
- `.ai/context/ARCHITECTURE.md` - Composants système, workflows, sécurité
- `.ai/context/DATABASE.md` - Schéma complet, relations, états machines
- `.ai/context/API.md` - Endpoints, authentification, flat responses pattern

**Développement** :
- `.ai/context/DEVELOPMENT_WORKFLOW.md` - TDD feature par feature, solutions critiques
- `.ai/context/TESTING.md` - Stratégie test complète avec exemples
- `.ai/context/lang-ruby/CODE-STYLE.md` - Conventions Ruby/Rails

**Documents Source** :
- `docs/TECHNICAL_DESIGN.md` - Document technique complet (source de vérité)
- `docs/WORKFLOW_IMPLEMENTATION_TDD.md` - Guide TDD détaillé
- `docs/SOLUTIONS_CRITIQUES.md` - Problématiques et solutions

## 💡 Development Guidelines

### Approche TDD Obligatoire
Suivre le cycle RED → GREEN → REFACTOR pour chaque feature.

**Ordre d'implémentation** :
1. Models + Tests
2. Interactors + Tests (si logique complexe)
3. Policies + Tests
4. Controllers + Request Specs
5. Cucumber Features (E2E)

### Code Style
- StandardRB (zero-config linting)
- Conventions Rails modernes
- Early returns pour réduire complexité
- Interactors pour logique métier complexe
- **Flat API responses** : pas de nesting sauf attachments dans data_packages

### Testing
- RSpec pour tests unitaires et request specs
- Cucumber pour workflows E2E
- Coverage minimum : 80%
- Utilisation intelligente de `let`, `let!`, `before`, `context`

### API Conventions
**IMPORTANT** : Les réponses Jbuilder sont plates (flat)
- ❌ Ne pas nester d'autres ressources complètes
- ✅ Exception unique : `attachments` dans `data_packages`
- ✅ Utiliser `_id` pour les relations (ex: `organization_id`)
- Clients font requêtes séparées pour naviguer relations

### Documentation
- Mettre à jour `.ai/context/` lors d'ajout de features majeures
- Documenter décisions architecturales importantes
- Garder `docs/TECHNICAL_DESIGN.md` à jour (source de vérité)

## 🔧 Commands Available

Custom slash commands are available in `.ai/commands/`. Check that folder for available automation.

## 👥 AI Agents

Specialized agents are configured in `.ai/agents/` for complex tasks like codebase exploration, deep search, etc.

---

**Note for AI Models**: This configuration is version-controlled. Always respect the guidelines defined here and in the context folders.
