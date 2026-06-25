---
name: uncle-dev-initiative-map
description: >
  Maps a large initiative into its big impacted items and a visual breakdown so the whole change can
  be seen before any spec or PRD work begins. Reads the objective plus existing platform context
  (codebase, architecture docs, feature maps), identifies every impacted feature, capability, service,
  application, and component across repos/platforms, captures their dependencies and cross-component
  interactions, names a stakeholder and SME per item, flags which decisions need an ADR, and writes a
  tiered YAML tracker plus a rendered map document (quick-view table, Mermaid breakdown diagram, a
  why/what/what-if/how detail per item) and a small stub file per big item. Use when scoping a big
  cross-platform change, when you need to visualize the shape and main workstreams of an initiative, or
  before deciding how to break it into PRDs/specs. Not for writing specs, tasks, or code — hand each
  stub to uncle-dev-grill or uncle-dev-spec, and each flagged decision to uncle-dev-documentation-and-adrs.
---
# Initiative Map

## Overview

Turns one high-level objective — a requirement, a high-level design, a major feature, a greenfield or
brownfield project, any large initiative — into a **visual breakdown of the big change**: the main
impacted items, how they connect, who owns them, and a diagram you can look at. It is the step *before*
PRDs and specs. Its only job is to make a large cross-platform change *legible* and sliceable.

It stops at a map plus one stub per big item. It does **not** write specs, tasks, or code, and it does
not run the heavy spec ceremony (no HLD/LLD/EARS, no pre-mortem). Those come later, per item, downstream.

## When to Use

- Scoping a large initiative that spans multiple applications, services, or components.
- You need to *see* the shape of a big change — its main workstreams and their interactions — before
  committing to any detailed spec.
- Deciding how to break an initiative into independently-workable pieces.
- Brownfield or greenfield; one repo or many.

NOT for:
- Writing the detailed spec for a single piece → use `uncle-dev-grill` then `uncle-dev-spec`.
- Breaking one approved change into implementation tasks → use `uncle-dev-planning-and-task-breakdown`.
- A pure code-explanation question → use `uncle-dev-research`.

## Core Process

### Phase 1 — Frame the initiative & detect scope
- Read the objective. If `$ARGUMENTS` is a file path, read it fully; if it's prose, use it directly.
  State your assumptions about what the initiative covers before going further.
- Detect **greenfield vs brownfield** and **single- vs multi-repo/platform** (scan working directories
  and dependency manifests).
- Pick a `<slug>` for the initiative (kebab-case).

### Phase 2 — Gather platform context (read-only)
- **Brownfield:** for each repo/platform, reuse an existing `.uncle-dev/feature-maps/*.md` if present;
  otherwise run `uncle-dev-feature-map` for that repo. Fan out parallel subagents for multi-repo.
- Read architecture docs: `docs/hld/`, root `README` architecture sections, and `AGENTS.md` files in
  affected directories.
- If `graphify-out/graph.json` or a `spec-graph` artifact exists, use it for the impacted/cascade signal
  (`graphify query "what does <area> touch"`).
- **Greenfield:** there is no code to inventory. Read the objective and any design docs only, and mark
  the map `greenfield (forward-looking)`.

### Phase 3 — Identify the big items (four lenses each)
- From objective × context, list every impacted **feature, capability, service, application, and
  component**. Keep them BIG — main workstreams only, named in **product language**, not code
  identifiers (`Unified checkout`, not `CheckoutController`).
- Give each item an `id` (`<tier>.<n>`, e.g. `1.1`) and per-item fields the tracker carries: `status`
  (`pending|in-progress|completed`), `domain`, `modules`/components touched, and `key_features`
  (the user-facing actions inside it — pull these from the feature-map in brownfield).
- For each item capture four **one-line** lenses (a phrase each, not a paragraph):
  - **Why** — the slice of the objective this item serves.
  - **What** — what gets built or changed.
  - **What if** — the risk lens: what breaks, leaks, or stalls if this item is wrong, skipped, or late.
  - **How** — a single-line implementation *idea* (the seed of an approach, not a design).
- Sizing check: if you have more than ~12 top-level items, you're too granular — roll up. One level of
  breakdown only; sub-items belong in the per-item stub later.

### Phase 4 — Map dependencies, then sequence into tiers, paths & milestones
- For each item, record what it **depends on** (A needs B first) and what it **interacts with** (A calls
  B's API, shares data, emits an event B consumes). These become the diagram's edges — solid for
  dependencies, dotted for runtime interactions.
- An item with no edges is suspect: either it's truly isolated (state that) or you haven't analyzed its
  interactions yet.
- From the dependency DAG, derive three roll-ups (mirroring the tracker schema):
  - **Tiers** — group items into ordered tiers by must-have→maturity (`MUST HAVE`, `HIGH VALUE`,
    `LATER`, `MATURITY`), with a one-line `sequencing` note per tier (what builds first within it).
  - **Critical paths** — the ordered dependency chains every other item waits on (e.g.
    `[accounts → transactions → reconciliation]`), each with a one-line rationale.
  - **Milestones** — phased delivery: which tiers/items compose each shippable phase.

### Phase 5 — Flag the decisions that need an ADR
Look at each item's **How** and **What if**: flag the item **ADR-needed** when a real technical
decision is hiding there — one of:
- multiple viable options with a real tradeoff (sync vs async, SQL vs queue, build vs buy),
- a hard-to-reverse or expensive-to-change choice,
- a cross-component contract/protocol or shared-data shape,
- a new technology, dependency, or external integration,
- a security, compatibility, or data-migration tradeoff.

Rules:
- **One ADR per decision, not per item** — several items can share one ADR (e.g. "event bus vs sync
  calls" spans order + notifications).
- Name each as a **question** ("Order→notify: sync REST or async events?"). Do **not** decide it here —
  authoring/deciding the ADR is `uncle-dev-documentation-and-adrs`, downstream.
- A routine item with one obvious approach needs **no** ADR. Don't manufacture decisions.

### Phase 6 — Assign stakeholder + SME per item
Name, per big item, a **stakeholder** (who wants/owns the outcome) and an **SME** (who knows the code/domain).
Source them — never invent names:
- SME signal, in order: `CODEOWNERS`, an `owner:` field in the area's `AGENTS.md`, then git
  top-committers of the impacted paths: `git shortlog -sn --no-merges -- <path>`.
- Stakeholder signal: a roster doc if one exists (e.g. `docs/stakeholders.md`), else ask the user.
- Unknown → write `TBD` and add it to Open Questions. A git committer is a *candidate* SME (people
  leave) — confirm rather than assert.

### Phase 7 — Write the tracker + the map document
Write two artifacts from the same data:
- **Canonical tracker** → `.uncle-dev/initiative-maps/<slug>-tracker.yaml` — machine-readable, following
  the Tracker Schema below (initiative meta, items with the four lenses + tier/status/deps/modules/ADR,
  tier summaries, global stats, critical paths, milestones, ADR register).
- **Rendered map** → `.uncle-dev/initiative-maps/YYYY-MM-DD-<slug>.md` — the human view: quick-view
  table, breakdown diagram, the detailed per-item list (the four lenses), and the ADRs-needed register.
  The markdown is generated *from* the tracker — they must not disagree.

### Phase 8 — Write one stub per big item
For each big item, write `.uncle-dev/initiative-maps/<slug>/<item-slug>.md` using the stub template.
Stubs are placeholders — the four lenses, touchpoints, deps, owner refs, and any ADR link only. No
acceptance criteria, no task lists, no code.

### Phase 9 — Present
Show the quick-view table, the breakdown diagram, and the ADRs-needed register inline. Point the user at
the map doc and the stub directory. For any item ready to go deeper, the next step is `uncle-dev-grill`
(PRD) or `uncle-dev-spec` (spec); for any flagged decision, `uncle-dev-documentation-and-adrs` (ADR).

## Tracker Schema (canonical YAML)

The machine-readable artifact. Generalized from a proven epics-tracker layout — keep these keys; drop
any domain-specific field (`new_endpoints`, `idempotency_required`, …) that doesn't apply, and add
others the initiative needs. One `item` per big item; `tier_summaries`, `critical_paths`, and
`milestones` are the roll-ups derived in Phase 4.

```yaml
initiative:
  name: <Initiative Title>
  slug: <slug>
  date: YYYY-MM-DD
  kind: greenfield | brownfield
  status: planning
  platforms: [<repo/app>, ...]
  total_items: <n>
  total_tiers: <n>

items:
  - id: "1.1"
    name: <Item name>
    tier: 1
    tier_name: "Foundations (MUST HAVE)"
    domain: <bounded area>
    status: pending            # pending | in-progress | completed
    why: <slice of the objective it serves>
    what: <what gets built/changed>
    what_if: <what breaks / is at risk if wrong, skipped, or late>
    how: <one-line implementation idea — the seed, not a design>
    modules: [<component/service>, ...]
    key_features: [<user-facing action>, ...]
    depends_on: []            # item ids
    interacts_with: []        # item ids (runtime: API/data/event)
    adr: []                   # ADR ids this item waits on
    spec_prefix: <SEGMENT-*>  # optional, if it will become a spec segment
    stakeholder: <name | TBD>
    sme: <name | TBD>
    open_questions: <n>
    stub: .uncle-dev/initiative-maps/<slug>/<item-slug>.md

tier_summaries:
  tier_1:
    name: "Foundations (MUST HAVE)"
    items: ["1.1", "1.2"]
    status: pending
    sequencing:
      - step_1: <what builds first within the tier>

critical_paths:
  sequence_1:
    order: 1
    path: ["<item>", "<item>", "<item>"]
    rationale: <why everything waits on this chain>

milestones:
  phase_1:
    name: <shippable phase>
    include_tiers: ["1"]
    include_items: ["1.1", "1.2"]

adrs_needed:
  - id: ADR-01
    decision: <decision as a question>
    items: ["1.1", "1.4"]
    options: [<opt A>, <opt B>]
    owner: <SME | TBD>
```

## Map Document Template

```markdown
---
date: YYYY-MM-DD
initiative: <slug>
kind: greenfield | brownfield
platforms: [<repo/app>, ...]
status: map
---

# Initiative Map: <Initiative Title>

## Objective
<one or two lines — the high-level goal, in the user's words>

## Quick View
| ID | Item | Tier | Type | Platform/App | Status | Depends on | ADR? | Stakeholder | SME |
|----|------|------|------|--------------|--------|-----------|------|-------------|-----|
| 1.1 | <name> | 1 MUST HAVE | service | payments | pending | — | ADR-01 | <name/TBD> | <name/TBD> |
| 2.1 | <name> | 2 HIGH VALUE | ui | web | pending | 1.1 | — | <name/TBD> | <name/TBD> |

## Breakdown
\`\`\`mermaid
flowchart TB
    INIT["<Initiative Title>"]
    INIT --> I1["<item 1>"]
    INIT --> I2["<item 2>"]
    I1 --> I3["<item 3>"]   %% solid = dependency
    I2 -.calls.-> I1        %% dotted = runtime interaction
\`\`\`

## Items (detail)
### 1. <Item name>
- **Why:** <slice of the objective it serves>
- **What:** <what gets built/changed>
- **What if:** <what breaks / is at risk if it's wrong, skipped, or late>
- **How:** <one-line implementation idea — the seed, not a design>
- **Touches:** <apps / services / components / key paths>
- **Depends on:** <sibling item names, or "none"> · **Interacts with:** <sibling + how (API/data/event)>
- **ADR:** <ADR-NN, or "none"> · **Stakeholder:** <name/TBD> · **SME:** <name/TBD>
- **Stub:** `.uncle-dev/initiative-maps/<slug>/<item-slug>.md`

## ADRs Needed
Technical decisions to resolve before/while implementing — author each with `uncle-dev-documentation-and-adrs`.
| ADR | Decision (as a question) | Items | Options (brief) | Owner |
|-----|--------------------------|-------|-----------------|-------|
| ADR-01 | <e.g. Order→notify: sync REST or async events?> | 1, 4 | <opt A / opt B> | <SME/TBD> |

## Open Questions
- <unknown owners, ambiguous boundaries, anything that needs a human>
```

## Per-Item Stub Template

```markdown
---
initiative: <slug>
item: <item-slug>
status: stub
stakeholder: <name | TBD>
sme: <name | TBD>
deps: [<sibling-item-slug>, ...]
adr: [<ADR-NN>, ...]   # decisions this item waits on; [] if none
---

# <Item name>

## Why
<the slice of the initiative's objective this item serves>

## What
<what gets built or changed — the boundary, not the implementation>

## What if
<what breaks / is at risk if this item is wrong, skipped, or late>

## How
<one-line implementation idea — the seed of an approach, not a design>

## Touches
<apps / services / components / representative paths>

## Dependencies & Interactions
- depends on: <...>
- interacts with: <... + how>

## Decisions (ADR)
- <ADR-NN: question to resolve>, or "none"

## Open Questions
- <...>

## Next
Run `uncle-dev-grill` (PRD) or `uncle-dev-spec` (spec) on this stub when ready to go deeper;
`uncle-dev-documentation-and-adrs` to settle any ADR above.
```

## Gotchas

- `uncle-dev-feature-map` is **single-repo** — run it once per repo/platform and merge; it will not span
  a multi-repo initiative on its own.
- Read project config only through `scripts/uncle-dev-config.sh`; never open `.agents/uncle-dev-setup.yaml`.
- Any spawned subagent must run the graphify on/off check (`[ -f graphify-out/graph.json ]`) before
  grep/Glob/Read, per the project CLAUDE.md.
- A frequent git committer is a *candidate* SME, not a confirmed owner — people change teams. Confirm.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just start writing the specs" | You can't spec what you can't see. The map exists to reveal the whole change and its interactions first; specs on an unmapped initiative miss cross-component work. |
| "A flat list of items is enough" | A list isn't a map. The value is the diagram — how the pieces depend on and call each other. Skip it and you skip the point. |
| "I can guess who the SME is" | Don't invent owners. Use CODEOWNERS / AGENTS.md / git signal, or mark `TBD`. A wrong name routes the work to the wrong person. |
| "Greenfield has no context to read" | It has the objective, constraints, and any design docs. Read them; mark the map forward-looking. |
| "Let me break it down to small tasks now" | Wrong grain. This is big-items only. Tasks come later, from specs, via `uncle-dev-planning-and-task-breakdown`. |
| "I'll put acceptance criteria in the stubs" | Stubs are placeholders. Criteria belong in the downstream spec, not here — keep the map cheap to redraw. |

## Red Flags

- Items named after code constructs (`OrderService.create`) instead of capabilities (`Order placement`).
- More than ~12 top-level items — too granular; roll up to main workstreams.
- A breakdown diagram with no edges — interactions weren't analyzed.
- Invented stakeholder or SME names instead of sourced-or-`TBD`.
- Stubs containing full specs, acceptance criteria, or task lists (scope creep into spec territory).
- No diagram at all — the visualization is the deliverable.
- Tracker YAML and the markdown map disagree (counts, items, deps) — they must be generated together.
- An ADR manufactured for an item with one obvious approach — flag decisions, don't invent them.
- Missing a lens (no "what if", or "how" written as a full design instead of a one-line seed).
- Running the heavy spec chain (HLD/LLD/EARS, pre-mortem) from inside this skill — that's downstream.

## Verification

- [ ] Canonical tracker saved to `.uncle-dev/initiative-maps/<slug>-tracker.yaml` (valid YAML)
- [ ] Rendered map saved to `.uncle-dev/initiative-maps/YYYY-MM-DD-<slug>.md`, consistent with the tracker
- [ ] Every item has an `id`, a `tier`, and all four lenses (why / what / what if / how) — each one line
- [ ] Quick-view table present (ID, Tier, Status, Depends on, ADR?, Stakeholder, SME)
- [ ] A Mermaid breakdown diagram is present, with dependency (solid) and interaction (dotted) edges
- [ ] `tier_summaries`, `critical_paths`, and `milestones` derived from the dependency DAG
- [ ] ADR register present; every flagged decision is phrased as a question and lists affected items
- [ ] Items needing no technical decision have no ADR (no manufactured decisions)
- [ ] Every item has a stakeholder and an SME, or an explicit `TBD` recorded in Open Questions
- [ ] One stub file exists per big item under `.uncle-dev/initiative-maps/<slug>/`
- [ ] Stubs contain the four lenses / touchpoints / deps / owner refs / ADR links only — no specs, tasks, or code
- [ ] Greenfield maps are marked `greenfield (forward-looking)`
