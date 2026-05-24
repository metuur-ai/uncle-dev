# OpenSpec Workflow Reference

Full process for `sdd_mode: openspec`. Follow phases in order — each requires human review before advancing.

```
BASELINE ──→ SCAFFOLD ──→ SPECIFY ──→ PLAN ──→ IMPLEMENT
    │            │           │         │          │
    ▼            ▼           ▼         ▼          ▼
  Human        Human       Human     Human      Human
 reviews      reviews     reviews   reviews    reviews
```

---

## Phase 0-OpenSpec — Initialize

Check if the OpenSpec CLI is available:

```bash
openspec --version
```

If installed:
- If `openspec/` does not exist: `openspec init`
- `openspec schemas` — see available workflow schemas
- `openspec templates` — discover artifact templates for the active schema

If not installed, recommend: `npm install -g openspec` and proceed with manual file creation.

**Graphify availability check — run once:**
```bash
[ -f graphify-out/graph.json ] && echo "graphify: ON" || echo "graphify: OFF"
```
If OFF, skip all graphify sections below.

---

## Phase 1 — Read Current Truth

Before drafting anything, understand the current state. With CLI:

```bash
openspec list --specs   # existing specs
openspec list           # open changes
openspec show <item>    # read a specific spec or change
```

Without CLI, read `openspec/specs/` and `openspec/changes/` directly.

### Graph-Augmented Baseline (skip if graphify: OFF)

```bash
# Read graphify-out/GRAPH_REPORT.md — identify god nodes and community boundaries

# Query the area of the proposed change:
graphify query "<describe the change area>" --budget 1500

# For a specific known module:
graphify explain "<module or concept>"
```

Add graph findings to your assumptions. Flag:
- **God nodes** adjacent to the change (high blast radius — may need broader spec scope)
- **Community crossings** (potential architectural layer violation — note in Boundaries)
- **Surprising connections** (add to "ask first" in Boundaries)

**Surface assumptions before writing.** List them explicitly:

```
ASSUMPTIONS I'M MAKING:
1. This service already uses OpenSpec as the tracked source of truth
2. The requested work belongs in a new change, not an update to an existing one
3. ...
→ Correct me now or I'll proceed with these.
```

---

## Phase 2 — Scaffold the Change

Every non-trivial change needs a tracked change ID. If the user didn't provide one, derive the next sequential ID:

- Scan `openspec/changes/` for `NNN-*` directories
- Next number = highest NNN + 1 (default `001` if none exist)
- Format: `NNN-descriptive-slug` (e.g., `003-auth-refresh`)
- Reject plain slugs like `my-feature` — the numeric prefix is required

Propose to the user: `"Next change ID: 003-<slug> — enter a slug or accept"`

### Scaffold with CLI

```bash
openspec change create <change-id>
openspec artifact add <change-id> execution.md
openspec artifact add <change-id> handoff.md
```

Without CLI, create `openspec/changes/<change-id>/` manually. Either way, ensure these five files exist:

- `proposal.md`
- `design.md`
- `tasks.md`
- `execution.md`
- `handoff.md`

### CLI Quick Reference

| Task | Command |
|------|---------|
| List changes | `openspec list` |
| Check status | `openspec status <change-id>` |
| Validate | `openspec validate <change-id>` |
| Show details | `openspec show <change-id>` |
| View dashboard | `openspec view` |
| Archive completed | `openspec archive <change-id>` |
| Artifact guidance | `openspec instructions <artifact>` |

---

## Phase 3 — Specify Change Truth

Use `openspec instructions <artifact>` before writing each file — it provides schema-aware guidance.

### Scope Mapping via Graph (skip if graphify: OFF)

Before writing `proposal.md`:

```bash
# Find all structural neighbors of the primary concept:
graphify explain "<primary module or concept>"

# For a change that bridges two subsystems:
graphify path "<subsystem-A>" "<subsystem-B>"
```

Use findings to populate `proposal.md` **Out of scope** and **Boundaries → Never** with graph-evidenced reasons.

For exact flow membership (not just neighbors), read hyperedges:

```bash
python3 -c "
import json
g = json.load(open('graphify-out/graph.json'))
for h in g.get('hyperedges', []):
    print(h['label'], '->', h['nodes'])
"
```

Use hyperedges when you need precise, named flow membership. Skip if fewer than 5 exist.

### Artifact Responsibilities

| Artifact | Content |
|----------|---------|
| `proposal.md` | Objective, problem framing, success criteria, scope, boundaries |
| `design.md` | Architecture, constraints, project structure, commands, testing approach, technical decisions |
| `tasks.md` | Shared story-level breakdown only — no code-level subtasks |
| `execution.md` | Cross-story sequencing, blockers, coordination notes |
| `handoff.md` | QA guidance, validation steps, rollout checklist |

Private scratch work and personal micro-steps belong in `.devlocal/<user>/`, never in shared tracked artifacts.

### Proposal Template

```markdown
# Proposal: [Change Name]

## Objective
[What we're building and why]

## Problem / User Impact
[Who is affected and what improves]

## Success Criteria
[Specific, testable conditions]

## Scope
[What is in and out]

## Boundaries
- Always: [...]
- Ask first: [...]
- Never: [...]
```

### Design Template

```markdown
# Design: [Change Name]

## Architecture
[Systems, components, and boundaries]

## Constraints
[Technical or delivery constraints]

## Project Structure
[Relevant paths and ownership]

## Commands
[Build, test, lint, validation commands]

## Testing Approach
[How this change will be verified]

## Technical Decisions
[Chosen approach and tradeoffs — append `→ ack` for decisions needing explicit sign-off]
```

### Flagging Decisions for Acknowledgement

When a technical decision in `design.md` is non-obvious, has a credible alternative, or breaks convention — append `→ ack`. After the human reviews `design.md`, run `/uncle-dev-acknowledge openspec/changes/<change-id>/design.md`. The skill extracts each `→ ack` row and writes it to `openspec/acknowledge/<scope>.md`. These block `/uncle-dev-build` until resolved.

---

## Phase 3.5 — Declare EARS Spec IDs (optional)

Only when the repo uses `docs/specs/`. Skip if that directory doesn't exist.

In `proposal.md`, add an `## EARS Specs` block:

```markdown
## EARS Specs
- Introduces: FAV-001, FAV-002
- Modifies: AUTH-005
```

For each declared ID:
- **Introduces**: add to `docs/specs/<segment>-specs.md` with status `[ ]` or `[x]`
- **Modifies**: re-read existing definition; edit in-place if wording sharpens; retire and introduce new ID if behaviour fundamentally changes

See `uncle-dev-spec-annotations` for ID format and `@spec` annotation rules.

---

## Phase 4 — Plan Shared Work

1. Break work into stories in `tasks.md` (shared coordination level only)
2. Record sequencing, blockers, and cross-story dependencies in `execution.md`
3. Use `.devlocal/<user>/<story-id>/scratchpad.md` for personal technical breakdown
4. `handoff.md` is the shared QA and validation guide

The output is reviewable: a teammate reading the change folder should be able to say "yes, this is the right change definition."

---

## Phase 5 — Implement With Promotion Rules

Execute stories one at a time per `uncle-dev-incremental-implementation` and `uncle-dev-test-driven-development`.

**Promotion protocol:**
- Personal dependency or team-impacting finding → promote to `tasks.md` or `execution.md`
- Experiment changes scope or design → promote to `design.md`
- Anything left in `.devlocal/` after merge is disposable

Never let `.devlocal/` be the only place a teammate would need to look for shared truth.

---

## Keeping the Spec Alive

- Update tracked artifacts when decisions change — before or alongside the code
- Commit change artifacts alongside code
- Reference the change in PRs
- Reconcile approved truth back into `openspec/specs/` once a change is accepted

---

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This is simple, I don't need a change folder" | Simple tasks don't need a large change, but they still need tracked shared truth. |
| "I'll write the change after I code it" | That's documentation, not specification. The folder exists to force clarity before code. |
| "Private notes are enough" | Private notes help one developer. Shared truth has to live in tracked artifacts. |
| "Requirements will change anyway" | That's why the change folder is living documentation. Updated specs beat chat-only context. |
| "I'll keep blockers in my scratchpad" | If it affects another person or story, it belongs in `execution.md` or `tasks.md`. |

## Red Flags

- Writing code without an active OpenSpec change
- Drafting a change without reading `openspec/specs/`
- Asking "should I just start building?" before clarifying what "done" means
- Implementing features not mentioned in the change folder
- Keeping cross-story dependencies only in `.devlocal/`
- Letting `tasks.md` turn into a personal code-level checklist

---

## Verification Checklist (OpenSpec mode)

- [ ] Active change exists at `openspec/changes/<change-id>/`
- [ ] All five artifacts present: `proposal.md`, `design.md`, `tasks.md`, `execution.md`, `handoff.md`
- [ ] `proposal.md`: objective, scope, success criteria, boundaries defined
- [ ] `design.md`: architecture, constraints, commands, testing approach defined
- [ ] `tasks.md`: shared story-level only (no code-level subtasks)
- [ ] `execution.md`: cross-story sequencing and blockers captured
- [ ] Human has reviewed and approved the shared change truth
- [ ] If repo uses `docs/specs/`: EARS spec IDs listed in `proposal.md ## EARS Specs`
