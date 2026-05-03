---
name: uncle-dev-planning-and-task-breakdown
description: Breaks an OpenSpec change into ordered shared stories and execution notes. Use when you have an approved proposal/design and need shared implementable units. Use when a task feels too large to start, when you need to estimate scope, or when parallel work is possible.
---

# Planning and Task Breakdown

## Overview

Decompose an approved OpenSpec change into shared story-level work and shared execution coordination. Good planning keeps tracked repo artifacts focused on team truth while allowing each developer to keep disposable technical scratch work in `.devlocal/`.

## When to Use

- You have a spec and need to break it into implementable units
- A task feels too large or vague to start
- Work needs to be parallelized across multiple agents or sessions
- You need to communicate scope to a human
- The implementation order isn't obvious

**When NOT to use:** Single-file changes with obvious scope, or when the spec already contains well-defined tasks.

## The Planning Process

**Graphify availability check** — run once before Step 1:
```bash
[ -f graphify-out/graph.json ] && echo "graphify: ON" || echo "graphify: OFF — using standard search"
```
If OFF, skip all graphify sections below and proceed with the standard process.

### Step 1: Enter Plan Mode

Before writing any code, operate in read-only mode. Check if the OpenSpec CLI is available (`openspec --version`). When available, use it to gather context:

- `openspec list` to see all active changes
- `openspec show <change-id>` to read the change's proposal and design
- `openspec status <change-id>` to check current artifact completion
- `openspec instructions tasks.md` to get enriched guidance for writing task breakdowns

If the CLI is not installed, recommend `npm install -g openspec` and read files directly:

- Read the relevant files in `openspec/specs/`
- Read the active change's `proposal.md` and `design.md`
- Identify existing patterns and conventions
- Map dependencies between components
- Note risks and unknowns

**Do NOT write code during planning.** The outputs are `tasks.md` and `execution.md`, not implementation.

### Step 2: Identify the Dependency Graph

Map what depends on what:

```
Database schema
    │
    ├── API models/types
    │       │
    │       ├── API endpoints
    │       │       │
    │       │       └── Frontend API client
    │       │               │
    │       │               └── UI components
    │       │
    │       └── Validation logic
    │
    └── Seed data / migrations
```

Implementation order follows the dependency graph bottom-up: build foundations first.

#### Graph-Augmented Dependency Mapping

> Skip if availability check returned OFF.

Before finalizing the dependency tree, run graph queries to catch non-obvious dependencies:

```bash
# 1. Read architectural signals
# Read graphify-out/GRAPH_REPORT.md — god nodes should be sequenced first (others depend on them)

# 2. For each major story candidate, explain its structural neighborhood:
graphify explain "<concept or module>"

# 3. Find structural paths between story areas that may share data:
graphify path "<story-A-module>" "<story-B-module>"

# 4. Find what depends on the module being changed:
graphify query "what depends on <module-being-changed>"
```

Add graph-discovered dependencies to the tree before slicing stories. Mark graph-sourced edges with `[graph]` so they can be verified if needed. Note any god nodes touched in the `## Shared Blockers` section of `execution.md`.

**Confidence rule:** Only add `[graph]` dependencies with EXTRACTED or INFERRED (>0.7) confidence to the dependency tree. AMBIGUOUS edges go into an "Open Questions" note in `execution.md` for manual verification.

**Also check hyperedges for story boundaries.** Hyperedges label named groups like "user onboarding flow" or "checkout pipeline" — these often map directly to story-sized units, more precisely than community clusters:

```bash
# Check density first — only useful if ≥ 5 hyperedges exist
python3 -c "
import json
g = json.load(open('graphify-out/graph.json'))
hs = g.get('hyperedges', [])
print(f'hyperedges: {len(hs)}')
for h in hs:
    print(h['label'], '->', h['nodes'])
"
```

- **≥ 5 hyperedges:** map each one that overlaps the change area to a candidate story; the hyperedge's `nodes` list is the story's module scope
- **< 5 hyperedges:** skip; use community structure from GRAPH_REPORT.md instead
- **Do NOT use hyperedges** to find call chains or dependency direction — use `graphify path` for that

See `uncle-dev-graphify-aware-analysis` for the full hyperedge decision table.

### Step 3: Slice at Story Level

Instead of tracking every private engineering step in the repo, create shared story-sized slices:

**Bad (repo noise):**
```
Task 1: Update DTO
Task 2: Rename helper
Task 3: Add API validation
Task 4: Add button loading state
```

**Good (shared stories):**
```
Story 1: User can create an account
Story 2: User can log in
Story 3: Billing owner can view invoice history
Story 4: Support can retry a failed charge safely
```

Each shared story should describe a meaningful outcome that can be assigned, discussed, and verified by the team.

### Step 4: Write Tasks

Write story-sized items into `openspec/changes/<change-id>/tasks.md`. Keep them at shared coordination level. Do not include personal code-level substeps, scratch notes, or exploratory prompts.

Each story should follow this structure:

```markdown
## Story [ID]: [Short descriptive title]

**Outcome:** One paragraph explaining what this story accomplishes.

**Acceptance criteria:**
- [ ] [Specific, testable condition]
- [ ] [Specific, testable condition]

**Verification:**
- [ ] Tests pass: `npm test -- --grep "feature-name"`
- [ ] Build succeeds: `npm run build`
- [ ] Manual check: [description of what to verify]

**Dependencies:** [Other story IDs, or "None"]
```

### Step 5: Order and Checkpoint

Write cross-story coordination into `openspec/changes/<change-id>/execution.md`.

Arrange stories so that:

1. Dependencies are satisfied (build foundation first)
2. Each story leaves the system in a working state
3. Shared checkpoints exist between phases
4. High-risk work appears early (fail fast)

Use `execution.md` for:

- Phase ordering
- Cross-story dependencies
- Shared blockers
- Coordination notes promoted from `.devlocal/`
- Team-visible execution checkpoints

Example:

```markdown
## Phase 1
- Story STORY-101 must land before STORY-102 and STORY-103

## Cross-Story Dependencies
- STORY-104 depends on API contract decisions in STORY-102

## Shared Blockers
- Waiting on payment provider sandbox credentials

## Checkpoint: After Stories 101-103
- [ ] All tests pass
- [ ] Application builds without errors
- [ ] Core user flow works end-to-end
- [ ] Review with human before proceeding
```

### Step 6: Keep Private Breakdown Private

Each developer can break their assigned story down inside:

```text
.devlocal/<user>/<story-id>/scratchpad.md
```

Use `.devlocal/` for technical substeps, personal TODOs, experiments, and prompt notes. If anything in that private workspace affects another developer or changes the shared plan, promote it back to `tasks.md`, `execution.md`, or `design.md`.

## Task Sizing Guidelines

| Size | Shared Scope | Example |
|------|--------------|---------|
| **S** | One assignable outcome | Add invoice list for billing owners |
| **M** | One feature slice with a few moving parts | Retry failed charge flow |
| **L** | Multiple distinct outcomes | Billing management suite |
| **XL** | Cross-cutting initiative | **Too large — break it down further** |

If a story is L or larger, break it down further before implementation. Shared tracked tasks should stay story-sized; code-level steps belong in `.devlocal/`.

**When to break a story down further:**
- It would take more than one focused session (roughly 2+ hours of agent work)
- You cannot describe the acceptance criteria in 3 or fewer bullet points
- It touches two or more independent subsystems (e.g., auth and billing)
- You find yourself writing "and" in the story title (a sign it is two stories)

## Shared Artifact Templates

```markdown
# tasks.md

## Story STORY-101: [Title]

**Outcome:** [...]

**Acceptance criteria:**
- [ ] [...]
- [ ] [...]

**Verification:**
- [ ] Tests pass: `...`
- [ ] Build succeeds: `...`
- [ ] Manual check: [...]

**Dependencies:** [...]
```

```markdown
# execution.md

## Phase Order
- [...]

## Cross-Story Dependencies
- [...]

## Shared Blockers
- [...]

## Coordination Notes
- [...]

## Checkpoints
- [ ] [...]
```

## Parallelization Opportunities

When multiple agents or sessions are available:

- **Safe to parallelize:** Independent stories with clear contracts, tests for already-implemented features, documentation
- **Must be sequential:** Database migrations, shared state changes, dependency chains
- **Needs coordination:** Stories that share an API contract or design dependency; track the dependency in `execution.md` first, then parallelize

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll figure it out as I go" | That's how you end up with missing dependencies and hidden blockers. Shared planning saves rework. |
| "The tasks are obvious" | Write the shared stories down anyway. Explicit stories surface hidden dependencies and ownership boundaries. |
| "Planning is overhead" | Planning is the task. Implementation without a plan is just typing. |
| "I can hold it all in my head" | Context windows are finite. Tracked stories and execution notes survive session boundaries and handoffs. |
| "I'll keep the detailed blockers in my scratchpad" | If it affects another person or story, it belongs in `execution.md`. |

## Red Flags

- Starting implementation without reading `proposal.md` and `design.md`
- `tasks.md` filled with personal code-level TODOs
- No verification steps in shared stories
- No `execution.md` coordination for cross-story dependencies
- All stories are XL-sized
- Dependency order isn't considered

## Verification

Before starting implementation, confirm:

- [ ] Every shared story in `tasks.md` has acceptance criteria
- [ ] Every shared story has a verification step
- [ ] Cross-story dependencies are recorded in `execution.md`
- [ ] Shared tracked artifacts stay at story level, not code-task level
- [ ] Private implementation breakdown goes to `.devlocal/`
- [ ] Checkpoints exist between major phases
- [ ] The human has reviewed and approved the plan
