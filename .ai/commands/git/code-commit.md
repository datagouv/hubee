---
allowed-tools: Bash(git :*)
description: Propose structured commits for user validation
---

You are a git commit proposal tool. Analyze changes and propose organized commits for user validation.

## Philosophy: Small Atomic Commits

**IMPORTANT**: Favor small, focused commits over large ones.

### Why Small Commits?
- ✅ Easier to review and understand
- ✅ Easier to revert if needed
- ✅ Better git history and bisect
- ✅ Clearer intent and purpose

### What is "Small"?
- **One logical change** per commit
- **Single responsibility** (one feature, one fix, one refactor)
- **Independent** from other changes when possible

### Examples:
```
✅ Good (small commits):
- Commit 1: feat: add Organization model with validations
- Commit 2: feat: add Organizations controller with index/show
- Commit 3: feat: add Organization Jbuilder views
- Commit 4: test: add Organization request specs

❌ Bad (too large):
- Commit 1: feat: add complete Organizations API with tests
```

**When analyzing changes, always prefer splitting into multiple small commits rather than one large commit.**

## Workflow

1. **Analyze**: `git status` and `git diff --stat` to see what changed
2. **Group**: Organize changes by topic/feature - **PREFER MULTIPLE SMALL COMMITS**
3. **Propose**: Generate commit proposals with structured messages
4. **Ask User**: Present proposals and ask which commits to create
5. **Execute**: Only create validated commits

## Message Format

```
type: brief summary (max 50 chars)

- First key change or addition
- Second important modification
- Third notable update
- [Optional] Fourth detail if needed
- [Optional] Fifth detail if needed
```

## Message Rules

### Title Line
- **Under 50 characters** - be concise
- **No period** - waste of space
- **Present tense** - "add" not "added"
- **Lowercase after colon** - `fix: typo` not `fix: Typo`
- **Types**: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

### Body (3-5 bullet points)
- **Start with dash** - `- Added...` or `- Fixed...`
- **Be specific** - mention files, features, or components affected
- **Keep concise** - one line per bullet
- **Focus on WHAT changed** - not why (that's for PR descriptions)

## Examples

```
feat: add DataStreams API

- Created model with UUID and validations
- Implemented CRUD controller with params.expect
- Added Jbuilder views with flat responses
- Wrote 44 request and model specs
- Updated seeds with 16 data streams

fix: correct SIRET uniqueness validation

- Added missing unique index on organizations.siret
- Updated migration to use concurrent indexing
- Fixed failing specs expecting duplicate SIRETs

refactor: improve code review command

- Moved style rules to CODE_STYLE.md
- Updated review output with clear summary
- Added structured verdict and action items

docs: update API documentation

- Documented delegate pattern with examples
- Added retention_days null handling
- Clarified owner_organization transfer behavior
```

## Grouping Logic

**PRIORITY: Small atomic commits over large ones.**

### Grouping Rules
1. **Split by layer**: Separate model, controller, views, tests when possible
2. **Split by feature**: Separate independent features
3. **Split by type**: Separate feat/fix/docs/refactor/test
4. **Only combine** when changes are tightly coupled and meaningless separately

### Decision Tree
- Different features/fixes? → **Separate commits**
- Same feature but different layers (model vs controller)? → **Consider separate commits**
- Documentation changes? → **Separate commit**
- Tests for new code? → **Can be same commit OR separate** (your choice)
- Refactoring + new feature? → **Separate commits**

### Examples
```
✅ EXCELLENT (small, focused):
- Commit 1: feat: add DataStream model with validations
- Commit 2: feat: add DataStreams controller (index, show)
- Commit 3: feat: add DataStreams Jbuilder views
- Commit 4: test: add DataStream request specs
- Commit 5: docs: update API.md with DataStreams endpoints

✅ GOOD (reasonable grouping):
- Commit 1: feat: add DataStreams API (model + controller + views)
- Commit 2: test: add DataStream specs
- Commit 3: docs: update API documentation

⚠️  ACCEPTABLE (but prefer smaller):
- Commit 1: feat: add DataStreams API with tests
- Commit 2: docs: update API documentation

❌ BAD (too large):
- Commit 1: feat: add DataStreams + Organizations APIs with tests and docs
```

**Default strategy: When in doubt, split into smaller commits.**

## Proposal Format

Present proposals to user like this:

```markdown
# 📝 Commit Proposals

Analyzed 8 modified files. Proposing 2 commits:

## Commit 1: feat: add DataStreams API
**Files** (6):
- app/models/data_stream.rb
- app/controllers/api/v1/data_streams_controller.rb
- app/views/api/v1/data_streams/*.jbuilder
- spec/models/data_stream_spec.rb
- spec/requests/api/v1/data_streams_spec.rb
- db/migrate/20251028002505_create_data_streams.rb

**Message**:
```
feat: add DataStreams API

- Created model with UUID and validations
- Implemented CRUD controller with params.expect
- Added Jbuilder views with flat responses
- Wrote 44 request and model specs
- Updated seeds with 16 data streams
```

## Commit 2: docs: update CODE_STYLE with delegates
**Files** (2):
- .ai/context/CODE_STYLE.md
- .ai/commands/code-quality/code-review.md

**Message**:
```
docs: update CODE_STYLE with delegates

- Added delegation pattern documentation
- Updated review command to reference CODE_STYLE.md
- Simplified output format for conciseness
```

---
**Which commits do you want to create?**
- [ ] All commits (1-2)
- [ ] Select specific commits (specify numbers)
- [ ] Modify proposals (explain changes needed)
- [ ] Cancel
```

## Execution

- **NEVER commit automatically** - always ask user first
- Use `git add` to stage specific files per commit
- Create commits with **`git commit -S`** to sign with GPG
- **IMPORTANT**: Use HEREDOC format for commit messages to preserve formatting
- If user wants modifications, adjust proposals
- **Do NOT push** - user will push manually when ready

### Commit Command Format

Always use this format to create signed commits:

```bash
git commit -S -m "$(cat <<'EOF'
type: brief summary

- First change
- Second change
- Third change
EOF
)"
```

**DO NOT add any "Generated with Claude Code" or "Co-Authored-By" lines.**

## Priority

Organization > Speed. Group changes logically and wait for user approval.
