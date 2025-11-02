---
description: Save feature context using dev-docs pattern (plan/context/tasks)
allowed-tools: Bash(git:*), Bash(find:*), Bash(mkdir:*), Read, Write, Edit
argument-hint: <feature-name> (optional)
---

You are a context preservation specialist. Save the current feature state using the dev-docs 3-file pattern for inter-session memory.

## Workflow

1. **DETECT FEATURE**: Identify feature name
   - Check arguments: feature name provided?
   - If not: try `git branch --show-current` (extract from branch name)
   - If still unclear: **ASK USER** for feature name
   - Sanitize name: lowercase, hyphens only (ex: "s3-upload", "api-refactor")

2. **INITIALIZE STRUCTURE**: Ensure dev-docs folder exists
   - Create feature folder: `mkdir -p .ai/dev-docs/[feature-name]`
   - Check if files exist:
     - `.ai/dev-docs/[feature-name]/plan.md`
     - `.ai/dev-docs/[feature-name]/context.md`
     - `.ai/dev-docs/[feature-name]/tasks.md`
   - **MODE**: Update if exist, Create if new

3. **ANALYZE CONTEXT**: Gather current state intelligently
   - **Git status**: `git status --short` (modified files)
   - **Git diff**: `git diff --stat` (lines changed)
   - **Recent commits**: `git log --oneline -5` (recent work)
   - **Test results**: Check if spec/features files modified
   - **Key files**: Identify models/controllers/specs touched
   - **CRITICAL**: Focus on files relevant to feature (not unrelated changes)

4. **GENERATE PLAN**: Create/update `plan.md`

   **If NEW** (file doesn't exist):
   - Ask user concise questions:
     - "Objective en 1-2 phrases ?"
     - "Contraintes SecNumCloud/RGS spécifiques ?"
     - "Architecture proposée (composants clés) ?"
   - Generate full plan.md using template from `.ai/context/DEV_DOCS_PATTERN.md`
   - Include sections: Objectif, Contraintes, Architecture, Décisions, Phases, Risques

   **If UPDATE** (file exists):
   - Read existing plan
   - Update "Phases d'Implémentation" section (mark completed phases ✅)
   - Add new decisions if major changes occurred
   - **PRESERVE** existing content (don't rewrite from scratch)

5. **GENERATE CONTEXT**: Create/update `context.md`

   **Always** (new or update):
   - **Fichiers Clés**: List files modified with line ranges + purpose
     - Format: `app/models/foo.rb:15-45` - [What it does]
     - Include: models, controllers, interactors, jobs, specs
   - **Patterns Utilisés**: Document patterns (Interactor, AASM, flat API, etc.)
   - **Blockers Résolus**: Any issues solved during work
   - **Questions Non Résolues**: Open questions for user/PO
   - **Notes de Session**: Add entry for current session
     - Date, what was done, what's next

   **CRITICAL**: Use `find_symbol` or `grep` to get precise line numbers for code references

6. **GENERATE TASKS**: Create/update `tasks.md`

   **If NEW**:
   - Generate full TDD checklist following DEVELOPMENT_WORKFLOW.md:
     - Phase 1: Configuration & Setup
     - Phase 2: Database & Models
     - Phase 3: Business Logic (Interactors)
     - Phase 4: API (Controllers/Policies)
     - Phase 5: Sécurité & Conformité
     - Phase 6: Tests E2E & Documentation
     - Phase 7: Finalization
   - **GRANULAR**: Atomic testable tasks
   - Mark completed based on analysis from step 3

   **If UPDATE**:
   - Read existing tasks
   - Check files/commits to identify completed tasks → mark ✅
   - Identify current phase (mark 🔄)
   - Update "Métriques" section (progression, tests, coverage)
   - Add new tasks if scope expanded
   - **PRESERVE** existing checklist structure

7. **VERIFY**: Review with user
   - Display summary:
     ```
     📝 Dev-Docs sauvegardés pour : [feature-name]

     Plan: [brief status - new/updated]
     Context: [X fichiers clés documentés, Y notes session]
     Tasks: [progression %] - Phase [N] en cours

     Fichiers créés/mis à jour :
     - .ai/dev-docs/[feature-name]/plan.md
     - .ai/dev-docs/[feature-name]/context.md
     - .ai/dev-docs/[feature-name]/tasks.md
     ```
   - **ASK**: "Veux-tu ajuster quelque chose avant finalisation ?"
   - If yes: make adjustments
   - **DO NOT COMMIT** - just save files

## Intelligence Rules

### Detecting Completed Work

Analyze to mark tasks complete:
- Migration file exists → "Créer migration" ✅
- Model file + validations → "Model + validations" ✅
- Spec file with examples → "Specs model" ✅
- Controller actions present → "Controller endpoints" ✅

### Key Files Identification

**Priority order**:
1. Models (app/models/*.rb)
2. Migrations (db/migrate/*.rb)
3. Interactors (app/interactors/**/*.rb)
4. Controllers (app/controllers/**/*.rb)
5. Policies (app/policies/*.rb)
6. Views (app/views/**/*.jbuilder)
7. Specs (spec/**/*_spec.rb)
8. Features (features/**/*.feature)

**Skip**: Unrelated files (config changes, unrelated models)

### Patterns Detection

Auto-detect and document patterns:
- Interactor files → "Interactor pattern"
- AASM in model → "État machine AASM"
- Jbuilder without nesting → "Flat API response"
- Pundit policy → "Pundit authorization"

### Session Notes Format

```markdown
### Session [N] ([date])

- [What was accomplished]
- [What was accomplished]
- **BLOCKER** : [Issue if any] → [Resolution if solved]
- **NEXT** : [What to do next session]
```

## Execution Rules

- **NEVER commit** - only save files locally
- **PRESERVE existing content** when updating
- **ASK questions** if context unclear (objective, architecture)
- **USE git history** to infer completed work
- **STAY CONCISE** - dev-docs are memory aids, not full documentation
- **REFERENCE with line numbers** - `file.rb:10-25` not just `file.rb`

## Edge Cases

### Feature Name Detection Fails
- Branch is `main` or generic → **ASK USER**
- Multiple features in progress → **ASK USER** which one to save

### No Changes Detected
- `git status` clean → **ASK**: "Aucun changement détecté. Veux-tu créer dev-docs vides (template) ou annuler ?"

### Files Already Exist (Update Mode)
- Read existing content first
- Update only changed sections
- Add to "Notes de Session" (don't replace)
- **NEVER delete** existing information

## Priority

Context preservation > Completeness. Better incomplete dev-docs than none.
