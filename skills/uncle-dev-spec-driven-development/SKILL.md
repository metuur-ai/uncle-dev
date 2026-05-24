---
name: uncle-dev-spec-driven-development
description: Creates tracked OpenSpec change artifacts before coding. Use when starting a new project, feature, or significant change and no specification exists yet. Use when requirements are unclear, ambiguous, or only exist as a vague idea.
---

# Spec-Driven Development

## Overview

Define tracked OpenSpec change artifacts before writing any code. Shared project truth lives in `openspec/specs/`. Shared change truth lives in `openspec/changes/<change-id>/`. Personal execution notes live in `.devlocal/` and are ignored by git. Code without tracked change artifacts is guessing.

## When to Use

- Starting a new project or feature
- Requirements are ambiguous or incomplete
- The change touches multiple files or modules
- You're about to make an architectural decision
- The task would take more than 30 minutes to implement

**When NOT to use:** Single-line fixes, typo corrections, or changes where requirements are unambiguous and self-contained.

**Graphify availability check** — run once before Phase 0:
```bash
[ -f graphify-out/graph.json ] && echo "graphify: ON" || echo "graphify: OFF — using standard search"
```
If OFF, skip all graphify sections below and proceed with the standard process.

## The Gated Workflow

Spec-driven development has five phases. Do not advance to the next phase until the current one is validated.

```
BASELINE ──→ SCAFFOLD ──→ SPECIFY ──→ PLAN ──→ IMPLEMENT
    │            │           │         │         │
    ▼            ▼           ▼         ▼         ▼
  Human        Human       Human     Human     Human
 reviews      reviews     reviews   reviews   reviews
```

### Phase 0: Read Project SDD Mode

Before any tool invocation, read the project's configured SDD mode:

```bash
CONFIG_LOOKUP="${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev-agent-skills/1.0.0/scripts/uncle-dev-config.sh"
bash "${CONFIG_LOOKUP}" preferences.sdd_mode openspec
```

**Route based on result:**

| `sdd_mode` | Starting flow |
|---|---|
| `openspec` (default / missing) | Continue to **Phase 0-OpenSpec** below — scaffold first, EARS near end |
| `lid-ears` | Jump to **Phase 0-LID** below — elicit requirements first, scaffold after |

---

#### Phase 0-LID: LID EARS Elicitation (when `sdd_mode: lid-ears`)

**STOP. Do not ask any OpenSpec questions. Do not propose change IDs. Do not ask about packaging or change structure. Do not run any `openspec` command. Complete this entire phase and receive explicit user confirmation before advancing to Phase 0-OpenSpec.**

Run this phase in full. The output becomes the input to `proposal.md` and `design.md`.

**L — Lenses** (ask, then document)

Surface who is affected and from which angle:
- Who are the users or systems that interact with this change?
- What is their current pain? What changes for them after this ships?
- Are there secondary consumers (other services, agents, hooks)?

**I — Intent** (ask, then document)

State what must be true when this change ships — not how, just what:
- What is the observable outcome from the user's perspective?
- What currently broken or missing behaviour gets fixed?
- What must NOT change (invariants)?

**D — Details** (ask, then document)

Surface non-negotiables, constraints, and boundaries:
- Platform, tool, or stack constraints (e.g., no MCP, macOS-only, agent-agnostic core)
- Compliance or security requirements
- Explicit out-of-scope items the user has already decided

After completing L, I, D — write the **EARS requirements table** before scaffolding:

Use the EARS keyword set:
- `THE SYSTEM SHALL` — always-on behaviour
- `WHEN <trigger>, THE SYSTEM SHALL` — event-driven
- `WHILE <state>, THE SYSTEM SHALL` — continuous during a condition
- `IF <condition>, THE SYSTEM SHALL` — conditional / compliance gates
- `WHERE <context>, THE SYSTEM SHALL` — location or environment scoped

Format as a table per unit of work:

```
| ID     | EARS statement |
|--------|----------------|
| R-1.1  | WHEN the user invokes /foo, THE SYSTEM SHALL … |
| R-1.2  | IF compliance.strict is true, THE SYSTEM SHALL … |
```

**HARD GATE — do not pass until the user explicitly confirms:**

Present the full LID EARS table and ask: *"Do these requirements look correct? Any changes before I scaffold the OpenSpec change?"*

Wait for the user's reply. Do not assume confirmation. Do not proceed to Phase 0-OpenSpec, do not propose a change ID, and do not run any `openspec` command until the user has responded "yes", "looks good", or equivalent.

After explicit user confirmation → continue to **Phase 0-OpenSpec**.

---

### Phase 0-OpenSpec: Ensure OpenSpec Is Initialized

Check if the OpenSpec CLI is available (`openspec --version`). If installed:

- If `openspec/` does not exist, run `openspec init` to scaffold the project structure
- Run `openspec schemas` to see available workflow schemas and select one if needed
- Run `openspec templates` to discover artifact templates for the active schema

If the CLI is **not** installed, recommend: `npm install -g openspec` and proceed with manual setup.

### Phase 1: Read Current Truth

Start by inspecting the current system truth before drafting a new change. When the CLI is available, use:

- `openspec list --specs` to see existing specs
- `openspec list` to see open changes
- `openspec show <item>` to read specific specs or changes

Otherwise, read the files directly:

- Read the relevant files in `openspec/specs/`
- Check whether there are related open changes in `openspec/changes/`
- Note assumptions, conflicts, and missing context before proposing anything new

#### Graph-Augmented Baseline

> Skip if availability check returned OFF.

Before surfacing assumptions, run a graph orientation to understand the current system structure:

```bash
# Read architectural signals
# Read graphify-out/GRAPH_REPORT.md — identify god nodes and community boundaries

# Query the area of the proposed change:
graphify query "<describe the change area in plain language>" --budget 1500

# If the change touches a specific known module:
graphify explain "<module or concept name>"
```

Add graph findings to the assumptions block. Flag in particular:
- Any **god nodes** the change is adjacent to (high blast radius; may require broader spec scope)
- **Community crossings** the change introduces (signals architectural layer violation worth noting in boundaries)
- **Surprising connections** to systems you didn't expect to touch (add these to "ask first" in Boundaries)

If the graph returns empty or only AMBIGUOUS edges, proceed as if this step was skipped.

See `uncle-dev-graphify-aware-analysis` for command syntax and confidence interpretation.

**Surface assumptions immediately.** Before writing any change content, list what you're assuming:

```
ASSUMPTIONS I'M MAKING:
1. This service already uses OpenSpec as the tracked source of truth
2. The requested work belongs in a new change, not an update to an existing one
3. This change affects the billing domain and not adjacent auth flows
4. The team wants shared coordination in tracked artifacts, not private notes
→ Correct me now or I'll proceed with these.
```

Do not silently draft a change against stale or missing baseline context. The point of the baseline read is to keep the new change aligned with the repository's current truth.

### Phase 2: Scaffold the Change

Every non-trivial change needs a tracked OpenSpec change id. If the human did not provide one, derive and propose the next sequential ID before scaffolding.

#### Change ID Convention

Change IDs must follow the format `NNN-descriptive-slug`, where `NNN` is a zero-padded three-digit counter:

- **Format:** `^\d{3}-.+` — e.g., `001-favorites-feature`, `002-auth-fix`, `015-dark-mode-toggle`
- **Derive the counter:** scan `openspec/changes/` for directories matching `NNN-*`, extract the highest `NNN`, and use `highest + 1` as the next number (default `001` if no changes exist)
- **Propose to the user:** `"Next change ID: 003-<descriptive-slug> — enter a slug or accept"`
- **Validate:** if the user provides a custom ID, reject any value that does not match `^\d{3}-.+` and re-prompt

**Red flag:** Never accept a plain slug like `my-feature` as a change ID — always require the numeric prefix.

#### Scaffolding with the OpenSpec CLI

Check if the OpenSpec CLI is available by running `openspec --version`. If it is installed, use it as the standard workflow:

```bash
openspec change create <change-id>
openspec artifact add <change-id> execution.md
openspec artifact add <change-id> handoff.md
```

If the CLI is **not** installed, recommend the user install it:

```
The OpenSpec CLI is not installed. Install it with:
  npm install -g openspec

The CLI automates change scaffolding, validation, and status tracking.
Proceeding with manual file creation for now.
```

Then fall back to manually creating the directory and files.

After scaffolding (via CLI or manually), ensure the active change folder exists at:

```text
openspec/changes/<change-id>/
```

And ensure it contains:

- `proposal.md`
- `design.md`
- `tasks.md`
- `execution.md`
- `handoff.md`

These tracked files replace the old `SPEC.md` and `tasks/` workflow as the default shared source of truth.

#### Using the CLI throughout the workflow

When the OpenSpec CLI is available, prefer it over manual file operations:

| Task | CLI command |
|------|------------|
| List changes | `openspec list` |
| View dashboard | `openspec view` |
| Check artifact status | `openspec status <change-id>` |
| Validate a change | `openspec validate <change-id>` |
| Show change details | `openspec show <change-id>` |
| Archive completed change | `openspec archive <change-id>` |

### Phase 3: Specify Shared Change Truth

When the CLI is available, use `openspec instructions <artifact>` to get enriched guidance for writing each artifact (e.g., `openspec instructions proposal.md`). This provides schema-aware templates and requirements.

#### Scope Mapping via Graph

> Skip if availability check returned OFF.

Before writing `proposal.md`, run a graph impact scan to find all concepts structurally connected to this change:

```bash
# Find all structural neighbors of the primary change concept:
graphify explain "<primary module or concept>"

# For each adjacent concept returned, decide: in-scope or out-of-scope?
# Add out-of-scope but graph-connected items explicitly to proposal.md Boundaries

# If the change bridges two subsystems:
graphify path "<subsystem-A>" "<subsystem-B>"
```

Use graph findings to populate the **Scope → Out of scope** and **Boundaries → Never** sections of `proposal.md` with graph-evidenced reasons. Example: *"Out of scope: PaymentProcessor — graph shows `conceptually_related_to` relation (INFERRED, 0.7) but no direct `calls` edge to the billing domain."*

**When to also use hyperedges here:** `graphify explain` gives a fuzzy BFS neighborhood. If you need the exact, named membership of a flow — not just adjacent nodes but "everything that officially participates in the checkout flow" — read hyperedges directly. This is especially useful for populating `proposal.md` **Scope → In scope** with a precise, graph-evidenced list:

```bash
python3 -c "
import json
g = json.load(open('graphify-out/graph.json'))
hs = g.get('hyperedges', [])
print(f'total hyperedges: {len(hs)}')
# Show all hyperedges — scan for ones matching the feature area
for h in hs:
    print(h['label'], '->', h['nodes'])
"
```

- **Use hyperedges** when you want exact flow membership to bound the spec scope
- **Skip hyperedges** when < 5 exist (too sparse to be useful) or when you only need direction/dependency chains (use `graphify path` instead)

See `uncle-dev-graphify-aware-analysis` for the full hyperedge decision table.

Start with a high-level vision. Ask the human clarifying questions until requirements are concrete, then distribute that truth across the change artifacts.

**Artifact responsibilities:**

1. **`proposal.md`** — Objective, user/problem framing, success criteria, scope, and boundaries
2. **`design.md`** — Architecture, constraints, project structure, testing approach, commands, and technical decisions
3. **`tasks.md`** — Shared story-level breakdown only
4. **`execution.md`** — Shared sequencing, cross-story dependencies, blockers, and promoted coordination notes
5. **`handoff.md`** — QA guidance, validation steps, and rollout/checklist notes

Do not push technical micro-steps or private scratch work into tracked shared artifacts. Those belong in `.devlocal/`.

**Proposal template:**

```md
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

**Design template:**

```md
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
[Chosen approach and tradeoffs]
```

**Reframe instructions as success criteria.** When receiving vague requirements, translate them into concrete conditions and store them in `proposal.md` rather than keeping them in chat-only form.

#### Flagging Decisions for Acknowledgement

When a row in `design.md` **Technical Decisions** is one the human still needs to sign off on — the chosen approach is non-obvious, has a credible alternative, or breaks an existing convention — append `→ ack` at the end of the row.

After the human reviews `design.md` (still in Phase 3, before moving to Phase 4), run `/uncle-dev-acknowledge openspec/changes/<change-id>/design.md`. The skill extracts every `→ ack` row, infers scope per `skills/uncle-dev-acknowledge/inference-rules.md` from the row text plus `proposal.md`'s Scope section, and writes each decision into `openspec/acknowledge/<scope>.md` linked to this change-id via `related_change`.

These notes are then `pending` and will block `/uncle-dev-build` from claiming any story whose touched scopes intersect with them — the human must run `/uncle-dev-acknowledge ack <ids>` (or `reject` / `supersede`) before implementation can begin.

This is the spec-flow's bridge to the gate. Lighter-weight than an ADR (which lives in `docs/decisions/` and is repo-wide narrative); use both when a decision deserves both per-package gating AND durable architectural history.

### Phase 4: Plan Shared Work

With the validated proposal and design, generate a shared story-level plan:

1. Break work into stories in `tasks.md`
2. Keep `tasks.md` at shared coordination level, not code-level subtasks
3. Record sequencing, blockers, and cross-story dependencies in `execution.md`
4. Use `.devlocal/<user>/<story-id>/scratchpad.md` for personal technical breakdown
5. Treat `handoff.md` as the shared QA and validation guide for the change

The output should be reviewable: the human should be able to read the change folder and say "yes, this is the right change definition" or "no, update X."

### Phase 5: Implement With Promotion Rules

Execute stories one at a time following `incremental-implementation` and `test-driven-development`. Keep the shared/personal boundary intact while you work.

**Promotion protocol:**

- **Coordination:** If personal breakdown reveals a dependency or team-impacting change, promote it to `tasks.md` or `execution.md`
- **Evolution:** If an experiment changes scope, design, or constraints, promote it to `design.md`
- **Disposability:** Anything left in `.devlocal/` after the story is merged is disposable

Never allow `.devlocal/` to become the only place where a teammate or future agent would need to look for shared truth.

## Keeping the Spec Alive

The change folder is a living source of truth, not a one-time artifact:

- **Update tracked artifacts when decisions change** — Change `proposal.md`, `design.md`, `tasks.md`, `execution.md`, or `handoff.md` before or alongside the code that depends on them
- **Commit the change artifacts** — Shared truth belongs in version control alongside the code
- **Reference the change in PRs** — Link back to the relevant artifact or section
- **Reconcile approved truth back into `openspec/specs/`** — Once a change is accepted, the project truth should eventually reflect it

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This is simple, I don't need a change folder" | Simple tasks don't need a huge change, but they still need tracked shared truth. A small OpenSpec change is fine. |
| "I'll write the change after I code it" | That's documentation, not specification. The change folder exists to force clarity before code. |
| "Private notes are enough" | Private notes help one developer. Shared truth has to live in tracked OpenSpec artifacts. |
| "Requirements will change anyway" | That's why the change folder is living documentation. An updated tracked change beats chat-only context. |
| "I'll just keep the blockers in my scratchpad" | If it affects another person or story, it belongs in `execution.md` or `tasks.md`. |

## Red Flags

- Starting to write code without an active OpenSpec change
- Drafting a change without reading `openspec/specs/`
- Asking "should I just start building?" before clarifying what "done" means
- Implementing features not mentioned in the change folder
- Keeping cross-story dependencies only in `.devlocal/`
- Letting `tasks.md` turn into a personal code-level checklist

### Phase 3.5: Declare EARS Spec IDs

If the repo uses durable behavior IDs (`docs/specs/`), every change must declare which IDs it touches. This is the bridge between the transient OpenSpec change (`openspec/changes/NNN-slug/`) and the durable spec graph (`docs/specs/`, `docs/arrows/`, `@spec` annotations in code).

In `proposal.md`, add an `## EARS Specs` block listing IDs the change introduces or modifies:

```markdown
## EARS Specs
- Introduces: FAV-001, FAV-002
- Modifies: AUTH-005
```

Then for each declared ID:

- **Introduces**: add the ID to `docs/specs/<segment>-specs.md` with status `[ ]` (active gap) or `[x]` (already implemented). For a new segment, also update `docs/arrows/index.yaml` and create `docs/arrows/<segment>.md`.
- **Modifies**: re-read the existing spec definition. If wording sharpens, edit it in place (the ID stays the same). If the behavior fundamentally changes, retire the old ID and introduce a new one.

The spec coverage tracker (`generate-tracker.py`) reads this block and emits a per-change `spec_coverage` field showing which IDs have code + test annotations. See `uncle-dev-spec-annotations` for ID format, segment selection, the `@spec` annotation rules, and the coherence scanner. See `uncle-dev-design-architecture-docs` if introducing a new segment.

If the repo does NOT use `docs/specs/`, skip Phase 3.5 (the convention is opt-in; everything else in this workflow still applies).

## Verification

Before proceeding to implementation, confirm:

- [ ] The active change exists under `openspec/changes/<change-id>/`
- [ ] `proposal.md`, `design.md`, `tasks.md`, `execution.md`, and `handoff.md` exist
- [ ] `proposal.md` defines objective, scope, success criteria, and boundaries
- [ ] `design.md` defines architecture, constraints, commands, and testing approach
- [ ] `tasks.md` contains shared story-level work only
- [ ] `execution.md` captures cross-story sequencing and blockers
- [ ] The human has reviewed and approved the shared change truth
- [ ] If the repo uses `docs/specs/`: every EARS spec ID introduced/modified by this change exists in `docs/specs/<segment>-specs.md` and is listed in `proposal.md`'s `## EARS Specs` block
