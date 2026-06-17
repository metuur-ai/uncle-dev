---
name: uncle-dev-spec-driven-development
description: >
  Drives spec-driven development before any code is written. Routes to LID+EARS mode
  (docs/hld → docs/lld → docs/ears documentation chain) or OpenSpec mode (tracked change
  artifacts in openspec/changes/) based on project config. Use whenever starting a new
  feature, significant change, or architectural decision; when requirements are ambiguous
  or only a vague idea; or when the task would take more than 30 minutes. Always invoke
  this skill before coding begins — code without a spec is guessing.
---

Design is the single source of truth. Intent flows downstream: HLD → LLD → EARS → code/tests. If all code were deleted, the spec documents must be sufficient to regenerate the project entirely.

## Phase 0 — Detect Mode and Route

Run this first, before any other tool call:

```bash
CONFIG_LOOKUP="${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev-agent-skills/1.4.0/scripts/uncle-dev-config.sh"
bash "${CONFIG_LOOKUP}" preferences.sdd_mode ""
```

| Result     | Path                                                            |
| ---------- | --------------------------------------------------------------- |
| `lid-ears` | Follow Phase 0-LID below. Never touch OpenSpec.                 |
| `openspec` | Read `references/openspec-workflow.md` and follow that process. |

---

<!-- UNCLE_DEV:BRANCH:lid-ears:START -->
## Phase 0-LID — LID+EARS Documentation Chain

Only when `sdd_mode: lid-ears`.

ABSOLUTE PROHIBITION: Do NOT run any `openspec` command. Do NOT propose change IDs. Do NOT load external skills. Do NOT advance to the OpenSpec flow. This path produces three documentation files and nothing else.

### Step 1 — Elicit (ask all three layers before writing anything)

Load upstream inputs first. If a PRD exists at `docs/prd/<slug>.md` (produced by `uncle-dev-grill`), use it as the source for Lenses/Intent/Details rather than re-eliciting from scratch. If requirements still live only in the user's head and this is a non-trivial feature, run `uncle-dev-grill` first to build a shared design concept. And if `docs/ubiquitous-language.md` (or `.uncle-dev/ubiquitous-language.md`) exists, read it and use its canonical terms throughout the HLD/LLD/EARS; if the domain has meaningful terminology and no glossary exists yet, run `uncle-dev-ubiquitous-language` before writing — aligned terms now prevent expensive renames later.

L — Lenses (feeds HLD)

- Who are the users or systems affected by this change?
- What is their current pain? What changes for them after this ships?
- Any secondary consumers (other services, agents, hooks)?

I — Intent (feeds HLD + LLD)

- What must be observable/true when this ships?
- What currently broken or missing behaviour gets fixed?
- What must NOT change (invariants)?

D — Details (feeds LLD)

- Platform, tool, or stack constraints
- Compliance or security requirements
- Explicit out-of-scope items already decided

### Step 2 — Write `docs/hld/<slug>.md`

Broad conceptual map. Audience: anyone who needs to understand _what_ and _why_, not _how_.

```markdown
# <Feature Title> — High-Level Design

## Overview

<one-paragraph summary of the change and its purpose>

## Stakeholders & Impact

<who is affected, current pain, what changes after shipping>

## Goals

<what must be observable/true when this ships>

## Non-Goals

<what must NOT change; explicit out-of-scope decisions>

## Success Criteria

<observable outcomes — how we know this is done>
```

### Step 3 — Write `docs/lld/<slug>.md`

Detailed modular breakdown. Audience: engineers implementing or reviewing the change.

```markdown
# <Feature Title> — Low-Level Design

## Architecture

<components, data flow, interfaces>

## Constraints

<hard technical constraints, platform limits, compliance rules>

## Key Decisions

<decisions and tradeoffs; rejected alternatives>

## Out of Scope

<items explicitly deferred>
```

### Step 4 — Write `docs/ears/<slug>.md`

Exact, structured behavioral requirements. Agents use these to generate tests and implementation. One table per logical unit of work. Each unit states its why — the intent behind its requirements — so downstream tasks and tests inherit the reason, not just the rule.

EARS keywords — use exactly as written:

- `THE SYSTEM SHALL` — always-on behaviour
- `WHEN <trigger>, THE SYSTEM SHALL` — event-driven
- `WHILE <state>, THE SYSTEM SHALL` — continuous during a condition
- `IF <condition>, THE SYSTEM SHALL` — conditional / compliance gate
- `WHERE <context>, THE SYSTEM SHALL` — location or environment scoped

```markdown
# <Feature Title> — EARS Specifications

## Unit 1: <name>

**Why:** <the intent this unit of work serves — the goal or user need behind these requirements>

| ID    | EARS statement            |
| ----- | ------------------------- |
| R-1.1 | WHEN … THE SYSTEM SHALL … |
| R-1.2 | IF … THE SYSTEM SHALL …   |
```

### Step 4.5 — Pre-mortem Risk Check

With the full spec drafted (HLD + LLD + EARS), run a pre-mortem before locking:

Invoke `/uncle-dev-pre-mortem` — pass the HLD goals + success criteria, LLD architecture + constraints, and EARS requirements as context. It imagines the initiative has completely failed and works backward to surface hidden risks.

Present the Top 5 Risks and mitigations from the pre-mortem output alongside the three spec documents at Step 5. The user may revise specs in response before confirming YES.

### Step 5 — HARD GATE

Present all three documents and the pre-mortem Top 5 Risks. Ask exactly this — nothing more:

> "Do these specs look correct and are the risks acceptable? Reply YES to lock them, or tell me what to change."

STOP. No follow-up questions. No options. No next steps. Wait silently.

### Step 6 — Confirm, save, and auto-chain into planning

After explicit YES from the user, write the three files, then tell them (concise — no prompts, no questions):

```
Specs locked. Saved:
  docs/hld/<slug>.md   — High-Level Design
  docs/lld/<slug>.md   — Low-Level Design
  docs/ears/<slug>.md  — EARS Requirements

Arrow of intent: HLD → LLD → EARS → code/tests.
To change a behaviour, update the EARS spec first — changes flow downstream.

Continuing into planning…
```

Then immediately invoke `/uncle-dev-plan` in the same turn. The YES at Step 5 is the user's authorization to complete the full define-time workflow (spec → plan). Do not stop and wait for the user to type the next command. The plan step enforces its own gate before any code is written.

Do NOT open openspec-workflow.md or run any openspec command.

---

## Verification (lid-ears)

- [ ] `docs/hld/<slug>.md` written with overview, stakeholders, goals, non-goals, success criteria
- [ ] `docs/lld/<slug>.md` written with architecture, constraints, key decisions, out of scope
- [ ] `docs/ears/<slug>.md` written with EARS table per unit of work
- [ ] `/uncle-dev-pre-mortem` run against HLD + LLD + EARS; Top 5 Risks presented at Step 5
- [ ] User has explicitly confirmed specs and risk profile before anything downstream was touched
- [ ] After YES, `/uncle-dev-plan` was invoked in the same turn (do not leave the user at a "run X next" pointer)
<!-- UNCLE_DEV:BRANCH:lid-ears:END -->

---

<!-- UNCLE_DEV:BRANCH:openspec:START -->
## OpenSpec Mode

When `sdd_mode` is `openspec`, read and follow `references/openspec-workflow.md`. It covers:

- Graphify baseline check
- Reading current OpenSpec truth
- Scaffolding the change (`openspec change create`)
- Writing proposal, design, tasks, execution, handoff artifacts
- EARS spec ID declarations (Phase 3.5)
- Verification checklist
<!-- UNCLE_DEV:BRANCH:openspec:END -->
