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

### Phase 0: Ensure OpenSpec Is Initialized

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

## Verification

Before proceeding to implementation, confirm:

- [ ] The active change exists under `openspec/changes/<change-id>/`
- [ ] `proposal.md`, `design.md`, `tasks.md`, `execution.md`, and `handoff.md` exist
- [ ] `proposal.md` defines objective, scope, success criteria, and boundaries
- [ ] `design.md` defines architecture, constraints, commands, and testing approach
- [ ] `tasks.md` contains shared story-level work only
- [ ] `execution.md` captures cross-story sequencing and blockers
- [ ] The human has reviewed and approved the shared change truth
