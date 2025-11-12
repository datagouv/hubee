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

## 🔐 SSH Commit Signing

**Status**: Required for this project

### SSH Configuration

All commits must be signed with SSH. This replaces the previous GPG signing setup.

**Benefits**:
- ✅ No PIN prompt required
- ✅ Works seamlessly with automation
- ✅ Compatible with AI-assisted commits

### Commit Commands

Commits are signed automatically with SSH:

```bash
# Stage your changes
git add <files>

# Commit (automatically signed with SSH)
git commit -m "type: description"

# Push to remote
git push origin <branch>
```

### SSH Troubleshooting

**Common Issues**:
1. **Signature failed**: SSH key not configured
   - **Solution**: Check `git config --global gpg.format ssh`
   - **Solution**: Verify `git config --global user.signingkey` points to your SSH public key

2. **Key not found**: Git can't find SSH key
   - **Solution**: Ensure SSH key is in `~/.ssh/` and added to ssh-agent

3. **GitHub verification**: Commits show as "Unverified"
   - **Solution**: Add your SSH signing key to GitHub (Settings → SSH and GPG keys → New SSH key → Signing Key)

## ⚠️ AI Agent Git Rules

**CRITICAL**: AI agents must NEVER commit directly without user validation

### AI Commit Workflow

1. ✅ **Analyze changes**: Review what needs to be committed
2. ✅ **Propose commits**: Show user what will be committed (title, body, files)
3. ✅ **Wait for validation**: User must explicitly approve
4. ✅ **Execute ONLY after approval**: Commit with user confirmation
5. ❌ **NEVER**: Auto-commit without asking

### Execution with SSH Signing

**AI agents can now execute commits directly** (SSH signing works without PIN prompt):
- ✅ Propose commit messages and file groupings
- ✅ Wait for explicit user validation ("yes", "ok", "go ahead")
- ✅ Execute commits using Bash tool **ONLY AFTER** approval
- ❌ NEVER execute without validation

**Example AI Response**:
```
I propose these commits:

## Commit 1: docs: update testing guidelines
**Files**:
- .ai/context/TESTING.md
- README.md

**Message**:
docs: update testing guidelines

- Updated RSpec conventions
- Added coverage requirements

## Commit 2: refactor: improve request specs
**Files**:
- spec/requests/api/v1/*.rb

**Message**:
refactor: improve request specs

- Simplified test structure
- Added shared examples

---

**Should I proceed with these commits?**
```

After receiving "yes" or "ok", the agent executes the commits using the Bash tool.

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

# Commit (automatically signed with SSH)
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
- [SSH Commit Signing Guide](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#ssh-commit-signature-verification)
- Project-specific: `.ai/AGENTS.md`, `.ai/context/DEVELOPMENT_WORKFLOW.md`

## 🆘 Getting Help

**For Git Issues**:
- Check this document first
- Review `.ai/context/DEVELOPMENT_WORKFLOW.md`
- Consult project README.md

**For SSH Signing Issues**:
- Verify SSH signing is enabled: `git config --global gpg.format ssh`
- Check signing key: `git config --global user.signingkey`
- Test SSH key: `ssh-add -l` (should list your key)
- Verify GitHub has your signing key: GitHub Settings → SSH and GPG keys

## 🔍 CI Validation

After pushing code to remote (in a PR), run the full CI suite locally:

```bash
bin/ci
```

This runs all tests, linters, and security checks locally before the remote CI runs. Execute only after code is pushed, not for local commits.

---

**Last updated**: 2025-11-12
**Related**: See `.ai/AGENTS.md` and `.ai/context/DEVELOPMENT_WORKFLOW.md` for development workflow
