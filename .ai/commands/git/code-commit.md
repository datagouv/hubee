---
allowed-tools: Bash(git status), Bash(git diff*), Bash(git log*)
description: Propose structured commits for user validation
---

You are a git commit proposal tool. Analyze changes and propose organized commits for user validation.

## Philosophy: Balanced Atomic Commits

**RULE**: Propose commits that are small enough to be clear, but large enough to be meaningful.

### Why Balanced Commits?
- ✅ Easier to review and understand
- ✅ Easier to revert if needed
- ✅ Better git history and bisect
- ✅ Clearer intent and purpose
- ✅ Not too granular to be noisy

### What is "Balanced"?
- **One logical unit** per commit (not too small, not too large)
- **Related files together** when they form a cohesive change
- **Separate concerns** (feat vs test vs docs vs refactor)
- **Group by layer** when it makes sense (migrations together, tests together, docs together)

### Default Splitting Strategy

**Group intelligently**:
1. **Database layer** → Group migrations together (they build the schema)
2. **Application layer** → Group model + controller + views (they form the API)
3. **Test layer** → Group all tests together (model spec + request spec + factory)
4. **Configuration** → Group routes + seeds (they wire things up)
5. **Documentation** → Group all docs together OR split if very different topics
6. **Refactoring** → Separate commit if touching existing code

### Examples:
```
✅ EXCELLENT (balanced atomicity):
- Commit 1: feat: add subscriptions database schema
  (migrations for table + UUID)
- Commit 2: feat: add Subscription model and controller
  (model + controller + views)
- Commit 3: refactor: add subscriptions associations
  (modifications to Organization + DataStream)
- Commit 4: feat: add subscription routes and seeds
  (routes.rb + seeds.rb + schema.rb)
- Commit 5: test: add subscription specs
  (model spec + request spec + factory)
- Commit 6: docs: update project documentation
  (API.md + TESTING.md + DATABASE.md + code-review.md)

✅ GOOD (slightly more granular):
- Commit 1: feat: add subscriptions migrations
- Commit 2: feat: add Subscription model
- Commit 3: feat: add SubscriptionsController and views
- Commit 4: feat: add subscription routes
- Commit 5: refactor: add subscriptions associations
- Commit 6: test: add subscription specs
- Commit 7: chore: seed subscription data
- Commit 8: docs: update API documentation
- Commit 9: docs: update conventions

⚠️ TOO GRANULAR (avoid):
- 15+ commits for a single feature
- One commit per file when files are tightly related
- Splitting migrations that form one schema change

❌ TOO LARGE (avoid):
- Commit 1: feat: add Subscriptions API with tests and docs
```

**Default strategy: Aim for 5-9 commits for a complete feature. Split by logical units, not by individual files.**

## Workflow

1. **Analyze**: `git status` and `git diff --stat` to see what changed
2. **Group**: Organize changes by topic/feature - **PREFER MULTIPLE SMALL COMMITS**
3. **Propose**: Generate commit proposals with structured messages
4. **Ask User**: Present proposals and **WAIT FOR EXPLICIT VALIDATION**
5. **Execute**: Create commits **ONLY AFTER** user approval

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

**PRIORITY: Balanced commits - clear intent, reasonable size.**

### Grouping Rules

**Group together (form logical units)**:
1. ✅ Related migrations that build one schema (create table + add UUID)
2. ✅ Model + Controller + Views for same resource (they form the API layer)
3. ✅ All tests for one feature (model spec + request spec + factory)
4. ✅ Configuration files that work together (routes + seeds + schema update)
5. ✅ Documentation on same topic (API.md + DATABASE.md if about same feature)

**Always separate**:
1. ✅ Database schema from application code
2. ✅ New feature from refactoring existing code
3. ✅ Tests from implementation (easier to review)
4. ✅ Documentation from code changes
5. ✅ Different features or unrelated changes

### Decision Tree
- Database changes (migrations)? → **Group migrations together, separate from app code**
- New model/controller/views? → **Group as "add X API layer"**
- Modifying existing models (associations)? → **Separate "refactor" commit**
- Routes + seeds + schema.rb? → **Group as "configure X"**
- All tests (specs + factory)? → **Group as "test X feature"**
- Multiple docs? → **Group if same topic, otherwise split**

### Examples
```
✅ EXCELLENT (5-6 commits, balanced):
- Commit 1: feat: add subscriptions database schema (2 migrations)
- Commit 2: feat: add Subscription API layer (model + controller + views)
- Commit 3: refactor: add subscriptions associations (Organization + DataStream)
- Commit 4: feat: configure subscription routes and seeds (routes + seeds + schema)
- Commit 5: test: add subscription specs (model + request + factory)
- Commit 6: docs: update conventions (API.md + TESTING.md + DATABASE.md)

✅ GOOD (8-9 commits, more granular):
- Commit 1: feat: add subscriptions migrations
- Commit 2: feat: add Subscription model
- Commit 3: feat: add SubscriptionsController and views
- Commit 4: refactor: add subscriptions associations
- Commit 5: feat: add subscription routes
- Commit 6: test: add Subscription model spec
- Commit 7: test: add subscriptions request spec and factory
- Commit 8: chore: seed subscription data
- Commit 9: docs: update project documentation

⚠️ TOO GRANULAR (15+ commits):
- One commit per file, even when tightly related

❌ TOO LARGE (2-3 commits):
- Everything in one "add feature" commit
```

**Default strategy: Aim for 5-9 commits. Group by logical units (layers, concerns, types), not individual files.**

## Advanced: Patch Mode for Split File Changes

When a single file contains **unrelated changes** that belong to different commits, use `git add -p` (patch mode).

### When to Use Patch Mode

**Use patch mode when**:
- ✅ A file has changes for multiple features mixed together
- ✅ Bugfix + refactor in the same file (separate commits)
- ✅ Different concerns in one file (e.g., validation + new method)
- ✅ Need to extract urgent fix from larger refactor

**Skip patch mode when**:
- ❌ All changes in the file are related (most cases)
- ❌ Changes are already well-separated by file

### How to Use

```bash
# Interactive staging by hunks
git add -p app/models/subscription.rb

# Git will ask for each change:
# Stage this hunk [y,n,q,a,d,s,e,?]?
# y = yes (stage this hunk)
# n = no (skip this hunk)
# s = split (divide into smaller hunks)
# e = edit (manually edit the hunk)
# q = quit
# ? = help

# After staging some hunks, commit
git commit -m "feat: add scopes"

# Then add remaining hunks
git add -p app/models/subscription.rb
git commit -m "refactor: simplify validations"
```

### Example Scenario

**File**: `app/models/subscription.rb`
- Lines 1-15: Added new scopes (Feature A)
- Lines 20-25: Fixed validation bug (Bugfix)
- Lines 30-40: Refactored associations (Refactor)

**Solution**:
```bash
# Stage only scope changes (lines 1-15)
git add -p app/models/subscription.rb  # Select 'y' for scopes, 'n' for rest
git commit -m "feat: add subscription filter scopes"

# Stage only bugfix (lines 20-25)
git add -p app/models/subscription.rb  # Select 'y' for bugfix, 'n' for rest
git commit -m "fix: correct permission_type validation"

# Stage remaining refactor (lines 30-40)
git add app/models/subscription.rb  # Add all remaining changes
git commit -m "refactor: simplify subscription associations"
```

### Note

**Most of the time, patch mode is NOT needed**. The default balanced commit strategy works well because changes are naturally separated by files and layers. Only use patch mode when truly necessary for cleaner history.

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

**Should I proceed with these commits?**
```

## Execution Mode

**CRITICAL**: All commits are signed with SSH (seamless signing without PIN prompts).

### Workflow

1. **Analyze & Propose**: Show all commit proposals with file lists
2. **Ask for Validation**: **ALWAYS** wait for explicit user approval
3. **Execute After Approval**: Create commits using Bash tool **ONLY AFTER** validation

### Rules

- ✅ **Commits are now automated** - SSH signing works without PIN prompt
- ❌ **NEVER execute `git commit` without user validation** - ALWAYS ask first
- ✅ After approval, execute commits directly using the Bash tool
- ✅ Chain git commands with `&&` for reliability
- ❌ **Do NOT push** - user will push manually when ready

### Validation Pattern

**Before executing any commit**:
1. Show complete commit proposals (title, body, file list)
2. Ask: "Should I proceed with these commits?"
3. Wait for explicit "yes" / "ok" / "go ahead"
4. Execute commits using Bash tool

### Execution Format

After receiving validation, execute commits using the Bash tool:

**CRITICAL RULES FOR GIT ADD**:
- ✅ **ONE `git add` per file or directory**
- ✅ Use explicit file paths (no wildcards unless necessary)
- ✅ Chain commands with `&&` for safety
- ✅ Use heredoc for multi-line commit messages

**Example**:
```bash
git add file1.rb && \
git add file2.rb && \
git add app/views/resource/ && \
git commit -m "$(cat <<'EOF'
feat: add feature

- First change
- Second change
- Third change
EOF
)"
```

**DO NOT add any "Generated with Claude Code" or "Co-Authored-By" lines.**

## Priority

Organization > Speed. Group changes logically and wait for user approval.
