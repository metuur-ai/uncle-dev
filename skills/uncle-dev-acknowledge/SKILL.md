---
name: uncle-dev-acknowledge
description: Captures design-decision notes as gating, package-scoped acknowledgements under openspec/acknowledge/. Notes are pending by default and block /uncle-dev-build from claiming any story in their scope until a human acks them. Use when the user pastes a list of "decisions worth checking", when /uncle-dev-spec surfaces decisions worth confirming during Phase 3, or when knowledge-capture detects a design decision (not a solved bug). Also handles ack/reject/supersede on existing decision IDs.
---

# Acknowledge

## Overview

Design decisions worth a human green-light belong neither in `.uncle-dev/learns/` (which is for solved problems) nor in `docs/decisions/` (which is heavyweight, repo-wide, narrative). They belong in `openspec/acknowledge/<scope>.md` — small per-package files of `### D<N>` sections that start as `status: pending` and **block `/uncle-dev-build` from claiming any story in their scope** until a human acknowledges them.

Once acknowledged, notes stay in place with `status: acknowledged` as citation history. The same file is the place to grep for "why did we do X" months later.

## When to Use

- The user pastes a list of decisions worth checking (e.g. "D5 constant-time login… D9 schema stays nullable…").
- `/uncle-dev-spec` Phase 3 review surfaces a design decision the human still needs to sign off on.
- `/uncle-dev-knowledge-capture` Step 0 routes here because the input is a design decision, not a solved bug.
- The user runs `/uncle-dev-acknowledge ack <ids>` to clear the gate, or `reject` / `supersede` to manage existing entries.
- A human wants to write notes by hand — read `note-schema.yaml` and edit the scope file directly.

**When NOT to use:**
- A bug was just solved → `uncle-dev-knowledge-capture` (writes to `.uncle-dev/learns/`).
- A repo-wide architectural decision needs a narrative record → `uncle-dev-documentation-and-adrs` (writes `docs/decisions/ADR-NNN-*.md`). Cross-link both ways when both apply.
- The note is just an inline code comment about *what* the code does → don't capture it; the code is the truth.

## Process

The skill operates in two modes: **capture** (parse new notes, write/update scope files) and **workflow** (ack/reject/supersede existing decisions). The slash command picks the mode from its arguments.

### Capture mode

1. **Parse input into discrete decisions.** Split on any of: `- D<N>` bullets, blank-line-separated paragraphs, numbered lists. Each decision has a one-line title and a rationale body. If the user already supplied a `D<N>` id, reuse it; otherwise allocate fresh ids in step 3.
2. **Run inference rules per decision.** For each decision body, apply the rule table in `inference-rules.md` to produce a scope set (one or more of `general`, `api`, `web`, `share`, or any project-specific scope). Record the matched signals as `inferred_from`.
3. **Allocate D-ids atomically.** Read `openspec/acknowledge/_meta.yaml` under a `mkdir`-style sentinel lock (same pattern as `skills/uncle-dev-next-task/parallelism-and-locks.md`). Increment `next_decision_id`, write back, release. Skip allocation for decisions whose id was supplied by the user.
4. **Write or update each scope file.**
   - Ensure `openspec/acknowledge/<scope>.md` exists with the standard header (create lazily if missing).
   - Ensure `openspec/acknowledge/general.md` always exists (create on first run with header only).
   - Append a new `### D<N>` section per `note-schema.yaml`, or update an existing section if the id already exists. Never edit the prose body of an existing section in capture mode — only the metadata bullet list.
5. **Print a routing summary.** Show one line per decision: `D<N> → [scopes] (signals: <matched>)`. The human can spot-check before moving on.

### Workflow mode

See `acknowledge-workflow.md` for the full mechanics. Quick reference:

- `ack <ids>` — flip `status: pending` → `status: acknowledged`, stamp `ack_by` (git user.email) + `ack_at` (UTC ISO-8601) in every file containing each id (propagation via `_meta.yaml` lookup).
- `reject <ids> --reason <r>` — flip to `status: rejected`, record reason in a new `- reject_reason: …` line. Rejected notes still satisfy the gate (the decision was made — to NOT do it).
- `supersede <old> --by <new>` — flip old to `status: superseded`, set `supersedes: <old>` on the new note. Both stay readable.
- `list [--scope <s>] [--status <s>]` — read-only summary, used by the gate and by humans browsing.

All workflow operations are sed-style **status-line rewrites only** — they touch the metadata bullets, never the prose.

## Inference Rules

Source of truth is `inference-rules.md`. Quick summary table (read the reference file for the precise grammar and edge cases):

| Signal in note text | Route to |
|---|---|
| Endpoint paths (`/auth/*`, `/api/*`), HTTP verbs, controller/route names | `api` |
| `migration`, `schema`, `prisma`, `table`, `column`, `nullable`, `index` | `api` + `share` |
| `render`, `route`, `page`, component names, `useEffect`, `tailwind`, `<Component>` | `web` |
| Type names, DTO, `interface`, `Zod`, contract, shared util | `share` |
| Path mention `apps/<x>/`, `packages/<x>/` | scope `<x>` (lazy create) |
| Negation pattern (`No /me endpoint`, `not introducing X`) | `general` + every scope the negated thing would have lived in |
| Cross-cutting concerns (security, perf budget, observability, error envelope, naming) | `general` (always) |
| Nothing matched | `general` only (fallback) |

**Duplication rule.** A note lands in every scope its signals match. It additionally lands in `general` when it's cross-cutting OR a negation. Duplicates share **one global D-id** so ack on any copy propagates to all (the workflow walks every scope file looking for that id).

## Acknowledge Workflow

See `acknowledge-workflow.md` for the propagation algorithm, lock handling, and the exact regex used for status-line rewrites. Honor the rule: **never edit prose during workflow operations**. Capture is the only mode that writes prose.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just remember to confirm the decisions later" | Memory fails. The whole point of the gate is to make `/uncle-dev-build` refuse to start until the human has actually said yes. |
| "Let me put everything in `general.md`" | Defeats per-package review. `web` reviewers shouldn't have to scan every cross-cutting decision to find the ones that affect the frontend. |
| "I'll write it as an ADR instead" | ADRs are repo-wide, durable, narrative — written once, kept forever. Acknowledge notes are per-package, lightweight, and ephemerally-blocking. They serve different purposes; both can apply to the same decision (cross-link). |
| "The decision is obvious — skip the gate" | If it were obvious, no one would have written a note about it. The gate enforces deliberate sign-off, not paperwork. |
| "I'll use `--ignore-acknowledgements` to unblock" | There is no such flag. The gate is non-bypassable by design. To unblock: ack, reject, or supersede. |
| "I'll just delete the section if I want to revoke an ack" | Don't. Use `reject` or `supersede`. Deleted history is lost history. |

## Red Flags

- A note that didn't match any inference signal but also didn't get the `general` fallback duplicate (routing bug — should always land somewhere).
- Status flipped to `acknowledged` but `ack_by` is empty (the workflow should refuse to write without a git user.email).
- Two decisions in different scope files with colliding D-ids that aren't actually duplicates of each other (`_meta.yaml` lock probably wasn't held).
- A workflow command that rewrites the prose body — only metadata bullets are mutable in workflow mode.
- A scope file missing its YAML frontmatter or its top-level `# Acknowledge: <scope>` header (parsers will skip it).
- D-ids not formatted as `D<N>` (the gate parser uses `^### D\d+` as the section anchor).

## Verification

After capture, confirm:

- [ ] Every input decision appears in at least one `openspec/acknowledge/<scope>.md` file.
- [ ] Every decision lands in `general.md` if it's cross-cutting or a negation pattern.
- [ ] `_meta.yaml` `next_decision_id` strictly exceeds the highest `D<N>` in any scope file.
- [ ] `openspec/acknowledge/general.md` exists with the standard header even if empty.
- [ ] Each new `### D<N>` section has all required metadata bullets per `note-schema.yaml`.
- [ ] The routing summary was printed and the human had a chance to spot-check.

After a workflow operation (`ack` / `reject` / `supersede`), confirm:

- [ ] Every file containing the affected D-id was updated (propagation across duplicates).
- [ ] Only the status line and ack/reject/supersede metadata changed; the prose body is byte-identical to before.
- [ ] `ack_by` and `ack_at` are populated from git config and current UTC time.
- [ ] Re-running `/uncle-dev-next-task` no longer reports the acked id as a blocker.
