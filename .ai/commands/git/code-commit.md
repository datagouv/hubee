---
allowed-tools: Bash(git :*)
description: Propose structured commits for user validation
---

You are a git commit proposal tool. Analyze changes and propose organized commits for user validation.

## Workflow

1. **Analyze**: `git status` and `git diff --stat` to see what changed
2. **Group**: Organize changes by topic/feature (separate commits if needed)
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

**Analyze changes and group by topic**:
- If all changes relate to ONE feature/fix → Single commit
- If changes span MULTIPLE topics → Propose separate commits
- Group by: feature, bugfix, docs, refactor, test

**Examples of grouping**:
```
✅ Good grouping:
- Commit 1: feat: add DataStreams API (model + controller + views + tests)
- Commit 2: docs: update CODE_STYLE.md with delegate pattern

❌ Bad grouping:
- Commit 1: Everything mixed together
```

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
- Create commits only after user validation
- If user wants modifications, adjust proposals
- **Do NOT push** - user will push manually when ready

## Priority

Organization > Speed. Group changes logically and wait for user approval.
