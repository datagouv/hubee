# Git Workflow - Hubee V2

> Git conventions and workflow for Hubee V2

## 🌿 Branching Strategy

**Primary Branch**: `main`

**Branch Types**:
- **Feature**: `feature/*` or `feat/*`
- **Bugfix**: `fix/*` or `bugfix/*`
- **Hotfix**: `hotfix/*`
- **Docs**: `docs/*`
- **Refactor**: `refactor/*`

### Branch Naming Convention

```bash
feat/description        # New feature
fix/description        # Bug fix
docs/description       # Documentation updates
refactor/description   # Code refactoring
```

## 📝 Commit Message Convention

**Format**: Conventional Commits

**Pattern**:
```
type(scope): description

[optional body]

[optional footer]
```

### Commit Types

| Type | Usage | Example from Project |
|------|-------|----------------------|
| `feat` | New feature | `feat: force JSON format for API controllers` |
| `fix` | Bug fix | `fix: login-bug` |
| `docs` | Documentation | `docs: add SOLID principles and security to CODE_STYLE` |
| `refactor` | Code refactoring | `refactor: simplify Jbuilder partial syntax` |
| `test` | Test changes | `test: add request specs for data_streams` |
| `chore` | Maintenance | `chore: update dependencies` |
| `style` | Code style changes | `style: fix StandardRB violations` |
| `perf` | Performance improvements | `perf: optimize query` |

### Commit Message Examples

**Good Examples from Project**:
```
docs: add SOLID principles and security to CODE_STYLE

feat: add delegate to DataStream model

refactor: improve code review and commit commands

docs: create compact CODE_STYLE.md
```

### Commit Philosophy

**Small, Atomic Commits**:
- One logical change per commit
- Each commit should be deployable
- Clear, descriptive commit messages
- No "WIP" or "fix" commit messages in main branch

## 🔐 GPG Commit Signing

**Status**: Required for this project

### GPG Configuration

All commits must be signed with GPG. If you encounter GPG timeout errors:

```bash
gpg: échec de la signature : Délai d'attente dépassé
```

**Workaround**: Use manual commit commands instead of automated tools to allow PIN entry in terminal.

### Manual Commit Commands

When automated commits fail due to GPG timeout:

```bash
# Stage your changes
git add <files>

# Commit with GPG signature (will prompt for PIN)
git commit -m "type: description"

# Push to remote
git push origin <branch>
```

### GPG Troubleshooting

**Common Issues**:
1. **Timeout**: GPG PIN prompt times out in background processes
   - **Solution**: Run git commands manually in terminal

2. **No PIN prompt**: GPG agent not configured
   - **Solution**: Check `gpg-agent` configuration

3. **Wrong key**: Git using incorrect GPG key
   - **Solution**: Check `git config --global user.signingkey`

## ⚠️ AI Agent Git Rules

**CRITICAL**: AI agents must NEVER commit directly without user validation

### AI Commit Workflow

1. ✅ **Analyze changes**: Review what needs to be committed
2. ✅ **Propose commits**: Show user what will be committed (title, body, files)
3. ✅ **Wait for validation**: User must explicitly approve
4. ✅ **Execute ONLY after approval**: Commit with user confirmation
5. ❌ **NEVER**: Auto-commit without asking

### When GPG Signing is Required

**AI agents should**:
- Propose commit messages and file groupings
- Provide manual commands for user to execute
- NOT attempt to execute `git commit` directly (will fail with GPG timeout)

**Example AI Response**:
```
I propose these commits:

1. docs: update testing guidelines
   Files: .ai/context/TESTING.md, README.md

2. refactor: improve request specs
   Files: spec/requests/api/v1/*.rb

Please run these commands:

git add .ai/context/TESTING.md README.md
git commit -m "docs: update testing guidelines"

git add spec/requests/api/v1/*.rb
git commit -m "refactor: improve request specs"
```

### Exceptions

**There are NO exceptions to the validation rule**. Even for:
- Documentation updates
- Test fixes
- Minor changes

Always ask user before committing.

## 🔀 Pull Request Workflow

### PR Creation

**Required Information**:
- Clear description of changes
- Link to related issues
- Test coverage confirmation
- Breaking changes (if any)

### PR Naming

**Pattern**: Same as commit convention

```
feat: add user authentication
fix: resolve login timeout
docs: update API documentation
```

## ✅ Code Review Process

### Review Requirements

**Minimum Approvals**: 1 (recommended)

**Required Checks**:
- Security checks passing (`rake security` - bundler-audit + brakeman)
- All tests passing (`bundle exec rspec`)
- StandardRB linting (`bundle exec standardrb`)
- Coverage > 80%

### Review Guidelines

**Reviewers Should Check**:
- Code follows project conventions (`.ai/context/lang-ruby/CODE-STYLE.md`)
- Tests are comprehensive (`.ai/context/TESTING.md`)
- Security best practices followed
- API responses: belongs_to nesté, has_many jamais (sauf attachments)
- Database migrations are reversible

## 🚀 Merge Strategy

**Merge Method**: Squash and merge (recommended for clean history)

**Merge Requirements**:
- All CI checks passing
- At least one approval
- No merge conflicts
- Branch up to date with main

### After Merge

**Actions**:
- Delete feature branch
- Verify deployment (if applicable)
- Close related issues

## 🔧 Git Hooks

### Pre-commit Hooks

**Potential Hooks** (not currently configured):
- StandardRB linting
- RSpec test run
- Brakeman security scan

### Manual Pre-commit Checks

Before committing, run:

```bash
# Security checks (bundler-audit + brakeman)
rake security
# or
rake security:all

# Lint code
bundle exec standardrb

# Run tests
bundle exec rspec
```

**Security Checks Details**:
- `rake security:bundler_audit` - Check for vulnerable gem dependencies
- `rake security:brakeman` - Static analysis for Rails vulnerabilities
- `rake security` or `rake security:all` - Run both checks

See `.ai/context/SECURITY_CHECKS.md` and `lib/tasks/security.rake` for more details.

## 📋 Issue Management

### Issue Linking

**Linking Pattern**: Use keywords in commit messages or PR descriptions

```
Fixes #123
Closes #456
Resolves #789
```

**Example**:
```
feat: add data stream export

Closes #123
```

## 🚦 Common Git Commands

### Creating a Feature Branch

```bash
# Create and switch to feature branch
git checkout -b feat/your-feature-name

# Make changes, then stage
git add <files>

# Commit (will prompt for GPG PIN)
git commit -m "feat: description of changes"

# Push to remote
git push -u origin feat/your-feature-name
```

### Making Changes

```bash
# Stage specific files
git add <file1> <file2>

# Commit with conventional format
git commit -m "type: description"

# Push changes
git push
```

### Updating Your Branch

```bash
# Fetch latest changes from main
git fetch origin main

# Rebase your branch on main
git rebase origin/main

# Force push if needed (after rebase)
git push --force-with-lease
```

### Creating a Pull Request

```bash
# Push your branch
git push -u origin feat/your-feature

# Use GitHub CLI to create PR
gh pr create --title "feat: your feature" --body "Description"

# Or create manually on GitHub web interface
```

## 📚 Resources

- [Conventional Commits](https://www.conventionalcommits.org/)
- [GPG Signing Guide](https://docs.github.com/en/authentication/managing-commit-signature-verification)
- Project-specific: `.ai/AGENTS.md`, `.ai/context/DEVELOPMENT_WORKFLOW.md`

## 🆘 Getting Help

**For Git Issues**:
- Check this document first
- Review `.ai/context/DEVELOPMENT_WORKFLOW.md`
- Consult project README.md

**For GPG Issues**:
- Verify GPG key configuration: `git config --global user.signingkey`
- Test GPG signing: `echo "test" | gpg --clearsign`
- Check GPG agent: `gpg-agent --daemon`

---

**Last updated**: 2025-10-31
**Related**: See `.ai/AGENTS.md` and `.ai/context/DEVELOPMENT_WORKFLOW.md` for development workflow
