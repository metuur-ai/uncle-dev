---
description: Start spec-driven development — define requirements before writing code
---

## Step 0 — Read SDD mode (do this first, before anything else)

```bash
CONFIG_LOOKUP="${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev-agent-skills/1.0.0/scripts/uncle-dev-config.sh"
SDD_MODE=$(bash "${CONFIG_LOOKUP}" preferences.sdd_mode openspec)
echo "${SDD_MODE}"
```

**Route based on result — pick exactly one path and follow it:**

---

## Path A — `lid-ears` mode

**If sdd_mode is `lid-ears`: follow this path.**

**ABSOLUTE PROHIBITION: Do NOT run any `openspec` command. Do NOT create change directories. Do NOT mention change IDs or OpenSpec artifacts. Do NOT load any external skill. This path produces three documentation files — nothing else.**

### The LID+EARS documentation chain

Intent flows in one direction only: **HLD → LLD → EARS → code/tests**. Design is the single source of truth. If all code were deleted, the three docs below must be sufficient to regenerate it entirely.

Execute this sequence:

---

### 1. Elicit — ask all three layers before writing anything

**L — Lenses (feeds HLD)**
- Who are the users or systems affected?
- What is their pain today? What changes for them after this ships?
- Any secondary consumers (other services, agents, hooks)?

**I — Intent (feeds HLD + LLD)**
- What must be observable/true when this ships?
- What currently broken behaviour gets fixed?
- What must NOT change (invariants)?

**D — Details (feeds LLD)**
- Hard constraints (platform, stack, tool restrictions)
- Compliance or security requirements
- Explicit out-of-scope items already decided

---

### 2. Write HLD — `docs/hld/<slug>.md`

Broad conceptual map. Audience: anyone who needs to understand *what* and *why*, not *how*.

```markdown
# <Feature Title> — High-Level Design

## Overview
<one-paragraph summary of the change and its purpose>

## Stakeholders & Impact
<who is affected, their current pain, what changes after this ships>

## Goals
<what must be observable/true when this ships>

## Non-Goals
<what must NOT change; explicit out-of-scope decisions>

## Success Criteria
<how we know this is done — observable outcomes>
```

---

### 3. Write LLD — `docs/lld/<slug>.md`

Detailed modular breakdown. Audience: engineers implementing or reviewing the change.

```markdown
# <Feature Title> — Low-Level Design

## Architecture
<how the pieces fit together — components, data flow, interfaces>

## Constraints
<hard technical constraints, platform limits, compliance rules>

## Key Decisions
<decisions made and why — tradeoffs, rejected alternatives>

## Out of Scope
<items explicitly deferred>
```

---

### 4. Write EARS specs — `docs/ears/<slug>.md`

Exact, structured behavioral requirements. Agents use these to write tests and implementation.

Use exactly these keywords:
- `THE SYSTEM SHALL` — always-on behaviour
- `WHEN <trigger>, THE SYSTEM SHALL` — event-driven
- `WHILE <state>, THE SYSTEM SHALL` — continuous during a condition
- `IF <condition>, THE SYSTEM SHALL` — conditional / compliance gate
- `WHERE <context>, THE SYSTEM SHALL` — location or environment scoped

One table per logical unit of work:

```markdown
# <Feature Title> — EARS Specifications

## Unit 1: <name>

| ID    | EARS statement |
|-------|----------------|
| R-1.1 | WHEN … THE SYSTEM SHALL … |
| R-1.2 | IF … THE SYSTEM SHALL … |

## Unit 2: <name>

| ID    | EARS statement |
|-------|----------------|
| R-2.1 | … |
```

---

### 5. HARD GATE
Present all three documents (HLD, LLD, EARS) and ask exactly this, nothing more:
> "Do these specs look correct? Reply YES to lock them, or tell me what to change."

**STOP. Do not ask follow-up questions. Do not offer options. Do not mention OpenSpec, change IDs, or next steps. Wait silently for the user's reply.**

---

### 6. After confirmation → confirm file locations

Only after explicit user confirmation. **No openspec commands. No change creation.**

Tell the user:
```
Specs saved:
  docs/hld/<slug>.md   — High-Level Design
  docs/lld/<slug>.md   — Low-Level Design
  docs/ears/<slug>.md  — EARS Requirements

Arrow of intent: HLD → LLD → EARS → code/tests.
To change a behaviour, update the EARS spec first, then let changes flow downstream.

Run /uncle-dev-plan when ready to break this into tasks.
```

---

## Path B — `openspec` mode (default)

**If sdd_mode is `openspec` or missing: follow this path.**

Invoke the agent-skills:uncle-dev-spec-driven-development skill and follow its full process:

1. Check `openspec --version` — init if needed
2. Read current specs (`openspec list --specs`) and open changes (`openspec list`)
3. Derive next change ID from `openspec/changes/` (format `NNN-slug`), propose to user
4. `openspec change create <id>` + `openspec artifact add <id> execution.md` + `handoff.md`
5. Ask clarifying questions (objective, users, acceptance criteria, constraints, boundaries)
6. Populate all five artifacts: `proposal.md`, `design.md`, `tasks.md`, `execution.md`, `handoff.md`
7. `openspec validate <id>` and confirm with user before proceeding

Private notes go in `.devlocal/`, not tracked artifacts.
