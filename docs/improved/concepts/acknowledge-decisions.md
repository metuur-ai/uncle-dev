---
sidebar_position: 4
---

# uncle-dev-acknowledge — Summary

A new skill that fills the gap between *thinking about* a design decision and *being allowed to build* it. It captures design-decision notes as package-scoped acknowledgements under `openspec/acknowledge/`, marks them `pending` by default, and **blocks `/uncle-dev-build` from claiming any story in their scope** until a human has explicitly said yes, no, or "superseded by something else."

## Why This Exists

Uncle Dev already has two places for recording decisions:

| Artifact | Where | Purpose |
|---|---|---|
| `.uncle-dev/learns/` | Knowledge capture | Solved bugs and workflow discoveries |
| `docs/decisions/ADR-NNN.md` | Documentation + ADRs | Durable repo-wide architectural history |

Neither was the right home for a message like this:

> - D5 (constant-time login) — every login runs argon2 even on unknown-email paths against a precomputed DUMMY_HASH so timing doesn't leak user existence.
> - D9 (User.passwordHash stays nullable in schema) — application-level "required for login," no migration needed.
> - No /me endpoint — login response is the single source of user + companies for first render. If you'd rather have /me to keep the login response slim, say the word and I'll restructure.

These are *not* solved bugs. They are *deliberate design choices that the human has not green-lit yet*. They belong to the `api` package, the `share` package, the `web` package — depending on the note. And they should *stop the agent from writing code* until a real human reads them and says "yes, proceed."

`uncle-dev-acknowledge` is the answer. The gap it fills:

```
/uncle-dev-spec          ← designs the change
  ↓ (decisions surface)
/uncle-dev-acknowledge   ← captures them, gates /uncle-dev-build
  ↓ (human: ack / reject)
/uncle-dev-build         ← now allowed to claim stories in those scopes
```

## How Notes Are Stored

Each `openspec/acknowledge/<scope>.md` is a long-lived Markdown file — one per package — that accumulates decision sections over time:

```
openspec/
  acknowledge/
    _meta.yaml       ← atomic D-id counter + scope index
    general.md       ← cross-cutting decisions; always exists
    api.md           ← created on first api-scoped note
    web.md
    share.md
    <any>.md         ← open set; any package name is valid
```

Each decision is a `### D<N>` section inside the appropriate file. One note can appear in multiple files when it spans packages — but it shares a single global D-id so acking it anywhere propagates everywhere.

A decision looks like this:

```markdown
<!-- decision-id: D5 -->
### D5 — constant-time login
- status: pending
- date: 2026-05-09
- inferred_from: ["DUMMY_HASH", "/auth/login", "argon2", "security"]
- related_change: 014-auth-hardening
- duplicated_in: [general]
- ack_by: null
- ack_at: null
- supersedes: null

Every login runs argon2 even on unknown-email paths against a precomputed
DUMMY_HASH so timing doesn't leak user existence. Identical 401 +
INVALID_CREDENTIALS for wrong-password / unknown-email / inactive / no-hash.
```

Status lifecycle: `pending` → `acknowledged` (or `rejected`, or `superseded`). Acknowledged notes stay in the file forever as citation history — the file is the long-term record of "why did we make that call."

## How Routing Works (Inference Rules, Not Configuration)

When you paste a block of notes into `/uncle-dev-acknowledge`, the skill reads each decision body and applies a deterministic rule table to assign it to one or more scope files. No LLM is involved — two agents always reach the same scope set for the same body.

The key patterns:

| Signal in the note body | Assigned to |
|---|---|
| Endpoint paths (`/auth/*`, `/api/*`), HTTP verbs, controller/middleware names | `api` |
| `schema`, `migration`, `prisma`, `nullable`, `table`, `column`, `index` | `api` + `share` |
| `render`, `page`, React hooks, Tailwind, JSX component names | `web` |
| `interface`, `Zod`, DTO, type name, shared contract | `share` |
| `apps/<x>/`, `packages/<x>/` path mentions | scope `<x>` (created lazily) |
| Negation pattern — `No /me endpoint`, `not introducing X` | `general` + every scope the negated thing would have lived in |
| Security, observability, rate limiting, error envelope, naming conventions | `general` (always, in addition to other matches) |
| Nothing matched | `general` (fallback — a note is never lost) |

**The duplication rule.** A single note lands in every scope its signals match. All copies share one D-id. Acking `D9` in `api.md` propagates to `share.md` automatically.

### Worked Example (the "D5/D6/D9/no-/me" block)

| Decision | Routed to | Why |
|---|---|---|
| D5 constant-time login | `api` + `general` | `/auth/login` → api; security cross-cutting → general |
| D6 chain shape | `api` | `/auth/login`, `/auth/refresh`, middleware/guard names → api only |
| D9 passwordHash nullable | `api` + `share` | `schema`, `nullable` → api+share |
| No /me endpoint | `general` + `web` + `api` | Negation pattern: would-have-lived-in api, consumed by web; cross-cutting → general |

After capture, `_meta.yaml` records `next_decision_id: 13` and `scopes: [general, api, web, share]`. Every D-id in every scope file is `pending`.

## How the Gate Works

The gate is Step 4b in the `uncle-dev-next-task` resolution process, between "compute ready set" and "rank and recommend."

For each story still in the ready set:

1. **Derive the story's touched scopes.** Sources in priority order: the `(scope: a, b)` annotation in `tasks.md`, then `apps/<x>/` path mentions in the story block, then package names in the change's `design.md` Technical Decisions. Fallback: `{general}`.
2. **Check against pending decisions.** If any `<scope>.md` under `openspec/acknowledge/` has a section with `status: pending` whose scope is in the story's touched scopes, the story is **blocked-by-acknowledgement**.
3. **Gate the recommendation.** If the recommended story is blocked, the picker emits the `BLOCKED:` block instead of the standard `READY SET` output. `--claim` refuses to acquire a lock.

The output the human sees:

```
BLOCKED: pending acknowledgements for scopes touched by 1.3 [api, share]
  • D5 (api) — constant-time login            openspec/acknowledge/api.md:14
  • D9 (api, share) — passwordHash nullable   openspec/acknowledge/api.md:48

Other stories in the ready set are also affected:
  • 1.4 [api]      blocked by D5, D6
  • 2.1 [share]    blocked by D9

To unblock:
  /uncle-dev-acknowledge ack D5,D9               # mark acknowledged
  /uncle-dev-acknowledge reject D5 --reason "…"  # reject + record
  Edit openspec/acknowledge/<scope>.md and flip `status:` manually

This gate is non-bypassable. After unblocking, re-run /uncle-dev-next-task.
```

**The gate is non-bypassable.** There is no `--ignore-acknowledgements` flag. The only way to proceed is to ack, reject, or supersede every pending decision in the touched scopes.

When there are no pending decisions (or `openspec/acknowledge/` doesn't exist yet), the gate is a complete no-op — zero performance impact.

## The Four Ways to Add Notes

### 1. Paste mode — `/uncle-dev-acknowledge`

Call the slash command with no arguments. It prompts for note text, parses the block into discrete decisions, infers scopes, allocates D-ids, writes the files, and prints the routing summary. Best for design sessions where a list of "things worth checking" has just been written.

### 2. Extract mode — from a spec design.md

In `/uncle-dev-spec` Phase 3, when writing `design.md`, append `→ ack` to any Technical Decisions row that still needs human sign-off:

```markdown
## Technical Decisions
- Use argon2 with precomputed DUMMY_HASH for constant-time login. → ack
- No /me endpoint — login response is the initial source for first render. → ack
```

After the human reviews the design, run:

```
/uncle-dev-acknowledge openspec/changes/014-auth-hardening/design.md
```

The skill extracts every `→ ack` row, infers scope from the row text plus the change's `proposal.md` Scope section, writes the notes into `openspec/acknowledge/<scope>.md`, and links them to this change via `related_change: 014-auth-hardening`.

Decisions captured at spec time gate build time.

### 3. Delegate from knowledge-capture

When `/uncle-dev-knowledge-capture` is invoked but the input is a design decision (not a solved bug), Step 0 routes it here automatically:

```
Is this a SOLVED PROBLEM or a DESIGN DECISION worth confirming?
  1. Solved problem  → continue with knowledge-capture (.uncle-dev/learns/)
  2. Design decision → delegate to /uncle-dev-acknowledge (openspec/acknowledge/)
```

The user picks, and the decision is captured in the right place without them needing to know which tool to reach for.

### 4. Hand-edit (no command)

The `openspec/acknowledge/<scope>.md` files are just Markdown with a specific section format. A human (or another agent) can write a `### D<N>` section directly, as long as it follows the schema in `skills/uncle-dev-acknowledge/note-schema.yaml`. The gate reads the files at runtime — no index to update manually, except `_meta.yaml`'s `next_decision_id` counter (which prevents D-id collisions; increment it if you write sections by hand).

## Workflow Commands

Once notes exist, these are the lifecycle operations:

| Command | What it does |
|---|---|
| `/uncle-dev-acknowledge ack D5,D9` | Marks D5 and D9 as acknowledged in every scope file that contains them. Stamps `ack_by` (git user.email) and `ack_at` (UTC). |
| `/uncle-dev-acknowledge reject D5 --reason "Not needed; argon2 is not available in this runtime"` | Marks D5 as rejected with the reason recorded. Rejected notes satisfy the gate — the decision was made (to NOT do it). |
| `/uncle-dev-acknowledge supersede D5 --by D12` | D5 is superseded by the new decision D12. Both stay readable; the gate no longer fires on D5. |
| `/uncle-dev-acknowledge list --scope api --status pending` | Read-only view of pending api decisions. Used before a review session to see what still needs sign-off. |

All workflow commands are **status-line rewrites only** — they never touch the prose body of a decision section. What the agent wrote, the agent doesn't silently rewrite.

## How It Fits Into the Full Uncle Dev Lifecycle

```
/uncle-dev-research      → understand the codebase
/uncle-dev-spec          → define the change (proposal, design, tasks, execution, handoff)
                             └─ Phase 3: append → ack to unresolved decisions in design.md
/uncle-dev-acknowledge   → capture those decisions into openspec/acknowledge/
                             └─ notes are now pending; gate is armed
  ↓
  human reads D5, D6, D9
  /uncle-dev-acknowledge ack D5,D6,D9
                             └─ gate clears for scopes api, share, general
  ↓
/uncle-dev-next-task --claim   → picks 1.3, no longer blocked
/uncle-dev-build               → implements story 1.3
/uncle-dev-test                → tests pass
/uncle-dev-review              → code review
/uncle-dev-ship                → PR + merge
```

At ship time, acknowledged notes stay in the file as a record of "decisions we deliberately made before building." Future agents and humans can grep `openspec/acknowledge/api.md` to understand *why* the login route works the way it does.

If a decision is reversed after the fact, use `reject` (if it was undone before implementation) or `supersede` (if a new decision replaces it). The history stays intact either way.

## Relationship to ADRs

Acknowledge notes and ADRs serve different needs. Use both when a decision deserves both.

| | ADR (`docs/decisions/`) | Acknowledge note (`openspec/acknowledge/`) |
|---|---|---|
| Scope | Repo-wide | Per package (general, web, api, share, …) |
| Weight | Full narrative — Context, Decision, Alternatives, Consequences | Lightweight — bullet metadata + one paragraph |
| Lifecycle | Accepted → Superseded; never deleted | Pending → Acknowledged/Rejected/Superseded; gates `/uncle-dev-build` while pending |
| When to use | A decision worth a durable architectural record | A decision a human needs to sign off on before implementation |
| Written by | Human or agent after the decision is made | Agent during spec or discovery, awaiting human review |

**Cross-linking.** When both apply: the ADR cites the D-id (`see also: D5 in openspec/acknowledge/api.md`), and the acknowledge note's rationale cites the ADR (`see ADR-007 for full alternatives considered`).

## Files Created by This Feature

```
skills/uncle-dev-acknowledge/
  SKILL.md                      ← main skill (Overview, Process, Inference Rules, Verification)
  inference-rules.md            ← the full routing table (edit here to tune routing)
  note-schema.yaml              ← file-level frontmatter + per-section metadata contract
  acknowledge-workflow.md       ← ack/reject/supersede mechanics, propagation, lock protocol

.claude/commands/
  uncle-dev-acknowledge.md      ← slash command (paste | extract | ack | reject | supersede | list)

skills/uncle-dev-next-task/
  acknowledge-gate.md           ← Step 4b algorithm, touched-scope derivation, BLOCKED output

openspec/acknowledge/           ← created lazily by the first /uncle-dev-acknowledge run
  _meta.yaml
  general.md
  <scope>.md (one per package)
```

Plus integration edits to five existing files:

| File | What changed |
|---|---|
| `skills/uncle-dev-next-task/SKILL.md` | Step 4b in the resolution diagram; BLOCKED output added to output contract |
| `skills/uncle-dev-next-task/parsing-and-annotations.md` | `scope` annotation key added to the recognized-keys table |
| `.claude/commands/uncle-dev-next-task.md` | Pending-ack added to Failure Modes |
| `.claude/commands/uncle-dev-build.md` | Non-bypassable BLOCKED handling added to Step 0 |
| `skills/uncle-dev-knowledge-capture/SKILL.md` | Step 0 routes design decisions to uncle-dev-acknowledge before entering capture modes |
| `skills/uncle-dev-spec-driven-development/SKILL.md` | Phase 3 "Flagging Decisions for Acknowledgement" subsection + `→ ack` row syntax |
| `skills/uncle-dev-documentation-and-adrs/SKILL.md` | ADR vs acknowledge-note comparison table |
| `CLAUDE.md` | `uncle-dev-acknowledge` registered under Define phase |

## What's Intentionally Not Done

- **No delete command.** Use `reject` (decision revoked) or `supersede` (replaced). Deleted history is lost history.
- **No LLM-based routing.** The inference table is deterministic and auditable. Two agents always route the same note to the same files.
- **No allowlist of valid scopes.** Any `<scope>.md` is valid. The system is open — new packages spring into existence on first note.
- **No caching.** The gate reads `openspec/acknowledge/` files fresh on every `/uncle-dev-next-task` call. Files are small; freshness is more valuable than speed.
- **No GUI.** The files are human-readable Markdown. `grep "status: pending" openspec/acknowledge/*.md` is always the escape hatch.

## Next Steps

1. Run `/uncle-dev-acknowledge` and paste in any "decisions worth checking" from your current spec.
2. Add `→ ack` to rows in your active `design.md` for decisions still needing sign-off.
3. Add `(scope: api, share)` annotations to stories in `tasks.md` to make the gate more precise (without annotations, scope is inferred from story prose, which works but is less explicit).
4. After a `/uncle-dev-next-task` run that shows `BLOCKED:`, run `/uncle-dev-acknowledge list --status pending` to review what needs acking, then `/uncle-dev-acknowledge ack <ids>` to clear the gate.
