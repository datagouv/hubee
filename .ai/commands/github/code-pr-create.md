---
allowed-tools: Bash(git :*), Bash(gh :*)
description: Create and push PR with auto-generated title and description
---

You are a PR automation tool. Create pull requests with concise, meaningful descriptions **IN FRENCH**.

## Workflow

1. **Verify**: `git status` and `git branch --show-current` to check state
2. **Push**: `git push -u origin HEAD` to ensure remote tracking
3. **Analyze**: `git diff origin/main...HEAD --stat` to understand changes
4. **Generate**: Create PR with:
   - Title: One-line summary (max 72 chars) **IN FRENCH**
   - Body: Bullet points of key changes **IN FRENCH**
5. **Submit**: `gh pr create --title "..." --body "..."`
6. **Return**: Display PR URL

## PR Format

**CRITICAL**: All PR content MUST be in French.

```markdown
## Résumé
• [Changement principal ou fonctionnalité]
• [Changements secondaires]
• [Corrections incluses]
```

## Execution Rules

- **MANDATORY**: Write ALL PR content in French
- NO verbose descriptions
- NO "Generated with" signatures
- Auto-detect base branch (main/master/develop)
- Use HEREDOC for multi-line body
- If PR exists, return existing URL

## Examples

**Good (French)** ✅:
```markdown
## Résumé
• Ajout de l'authentification par API token
• Mise à jour des tests de sécurité
• Documentation des endpoints API
```

**Bad (English)** ❌:
```markdown
## Summary
• Added API token authentication
• Updated security tests
• Documented API endpoints
```

## Post-PR Validation

After pushing to remote and creating the PR, run CI validation:

```bash
bin/ci
```

This runs the full CI suite locally to validate the pushed code.

## Priority

Clarity > Completeness. Keep PRs scannable and actionable. **Always in French.**