# Parsing tasks.md and Annotation Grammar

Reference for parsing `openspec/changes/<id>/tasks.md` files. Loaded by the picker; not read by humans during normal use.

## File Shape

```markdown
# Change Title

## Overview
<prose, ignored by the picker>

## Stories

### Story 1.1: Short title
**Outcome:** prose
**Acceptance criteria:**
- [ ] Specific testable condition
- [ ] Specific testable condition
**Dependencies:** None
**Annotations:** (deps: none) (mutex: none) (est: 30m)

### Story 1.2: Another title
**Acceptance criteria:**
- [ ] ...
**Annotations:** (deps: 1.1) (mutex: schema) (est: 45m)
```

The picker only cares about story headers, the unchecked-box state, and the **Annotations** line. Everything else is human prose.

## Story ID Rules

- IDs match the regex `^[0-9]+(\.[0-9]+)*$` — `1`, `1.2`, `1.2.3` are all valid
- Story IDs are **document-unique** within a single `tasks.md`
- Cross-change references use `<change-id>:<story-id>` (e.g., `dashboard-refactor:2.1`)

## Status Detection

A story is **complete** when ALL of these are true:
- Every `- [ ]` under "Acceptance criteria" is `- [x]`
- Every `- [ ]` under "Verification" (if present) is `- [x]`

A story is **in-flight** when:
- Some criteria are checked, some are not
- AND there is a matching `.devlocal/<user>/<story-id>/scratchpad.md` modified within 7 days

Otherwise, a story is **pending**.

The picker treats **pending** and **in-flight** the same for ready-set computation, but ranks **in-flight** higher (resume what was started).

## Annotation Grammar

Annotations live on a single line starting with `**Annotations:**` inside the story block. Format:

```
**Annotations:** (key: value) (key: value) (key: value)
```

Each `(key: value)` pair is space-separated. Whitespace inside parens is tolerated. Values may not contain `)`.

### Recognized Keys

| Key | Type | Meaning | Default if missing |
|---|---|---|---|
| `deps` | comma-separated story-ids OR `none` | Stories that must be complete first | `none` |
| `mutex` | tag string OR `none` | Two stories with the same mutex tag cannot run in parallel | `none` |
| `est` | duration (`30m`, `2h`, `1d`) | Rough effort estimate; used for tie-breaking | unknown (treated as median) |
| `risk` | `low` / `med` / `high` | Optional risk hint, surfaced in output | `low` |
| `agent` | agent-name | Hints which agent should pick this (informational only) | any |
| `scope` | comma-separated scope names (e.g. `api, share`) OR `none` | Authoritative declaration of which `openspec/acknowledge/<scope>.md` files gate this story; consumed by the acknowledge gate (see `acknowledge-gate.md`). When absent, scope is inferred from path mentions in the story block; the `none` literal is treated the same as missing (falls back to `{general}`). | inferred (or `{general}` as final fallback) |

### Cross-Change Dependencies

`deps:` may reference stories in other changes:

```
**Annotations:** (deps: dashboard-refactor:2.1, 1.2) (mutex: none)
```

The picker resolves cross-change deps by reading the referenced change's `tasks.md`. If the referenced change is not found, treat the dep as **unsatisfiable** and emit a warning — the user probably renamed or deleted the change.

### Mutex Across Changes

Mutex tags are global across all in-progress changes. Convention:

| Tag | Meaning |
|---|---|
| `schema` | Modifies `db/migrations/` or `prisma/schema.prisma` |
| `config` | Modifies project-wide config files |
| `auth` | Touches the auth/session module |
| `<custom>` | Project-specific shared resource |

Two stories declaring the same `mutex` tag — even from different changes — block each other. This is how parallel work across `auth-rework` and `dashboard-refactor` stays safe when both happen to touch the auth boundary.

## Cross-Change Mutex via proposal.md

For changes that should never run in parallel as a whole, declare the mutex in the change's `proposal.md` frontmatter:

```yaml
---
id: auth-rework
status: in-progress
mutex: auth
---
```

When set at the change level, every story inherits the mutex. Per-story `(mutex: ...)` annotations override the inherited value (use `(mutex: none)` to opt out).

## Backwards Compatibility

`tasks.md` files written before this skill existed have no annotations. The picker degrades gracefully:

- Missing `**Annotations:**` line → all defaults apply (no deps, no mutex, unknown est)
- Missing `deps:` → fall back to **document order**: each story implicitly depends on the previous one in the file
- Missing `mutex:` → no mutual exclusion
- Missing `est:` → treat as median for tie-breaking

Document-order fallback is conservative — it serializes everything — but safe. Once a project starts adding annotations, parallelism kicks in story-by-story.

## Parser Robustness

The parser must:

- Tolerate Windows line endings (`\r\n`)
- Tolerate trailing whitespace on annotation lines
- Tolerate annotations split across multiple lines if each line starts with `(` (rare but seen in long dep lists)
- Surface parse errors per-story rather than aborting the whole file — one bad story shouldn't hide the rest

When a story has an unparseable annotation, drop it from the ready set and emit a warning. Do not silently apply defaults — that masks bugs in the spec.

## Example: Full Story Block

```markdown
### Story 2.3: Add audit log sink for auth events

**Outcome:** Auth events (login, logout, password change) are written to the
audit log table. Failed logins include rate-limit context.

**Acceptance criteria:**
- [x] Schema migration adds `auth_events` table
- [ ] `AuthLogger` class writes events
- [ ] Unit tests cover login, logout, failed-login paths
- [ ] Integration test verifies event lands in audit table

**Verification:**
- [ ] `npm test -- auth-logger` passes
- [ ] `npm run build` succeeds

**Dependencies:** Story 1.4 (Logger middleware), Story 2.1 (auth_events schema)

**Annotations:** (deps: 1.4, 2.1) (mutex: auth) (est: 1h) (risk: med)
```

Parsing this:
- Story id: `2.3`
- Status: in-flight (1 of 4 acceptance boxes checked)
- Deps: `1.4`, `2.1`
- Mutex: `auth`
- Est: `60m`
- Risk: `med`
