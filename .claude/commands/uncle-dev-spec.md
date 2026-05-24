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

**If sdd_mode is `lid-ears`: follow this path. Do NOT mention OpenSpec, change IDs, or scaffolding until the user confirms the requirements table.**

Invoke the agent-skills:uncle-dev-spec-driven-development skill for reference context, then execute this sequence:

### 1. L — Lenses
Ask and document:
- Who are the users or systems affected?
- What is their pain today? What changes after this ships?
- Any secondary consumers?

### 2. I — Intent
Ask and document:
- What must be observable/true when this ships?
- What currently broken behaviour gets fixed?
- What must NOT change?

### 3. D — Details
Ask and document:
- Hard constraints (platform, tool, no-MCP, agent-agnostic, etc.)
- Compliance or security requirements
- Explicit out-of-scope items already decided

### 4. EARS requirements table
Write one table per unit of work using these keywords:
- `THE SYSTEM SHALL` — always-on
- `WHEN <trigger>, THE SYSTEM SHALL` — event-driven
- `WHILE <state>, THE SYSTEM SHALL` — continuous
- `IF <condition>, THE SYSTEM SHALL` — conditional / compliance
- `WHERE <context>, THE SYSTEM SHALL` — scoped

Format:
```
| ID    | EARS statement |
|-------|----------------|
| R-1.1 | WHEN … |
```

### 5. HARD GATE
Present the full table and ask exactly this, nothing more:
> "Do these requirements look correct? Reply YES to lock them, or tell me what to change."

**STOP. Do not ask any follow-up questions. Do not offer options. Do not mention OpenSpec, change IDs, or next steps. Wait silently for the user's reply.**

### 6. After confirmation → scaffold
Only after explicit user confirmation:
- Check `openspec --version`
- Derive next change ID from `openspec/changes/` (format: `NNN-slug`)
- `openspec change create <id>` + add `execution.md` and `handoff.md`
- Populate `proposal.md`, `design.md`, `tasks.md`, `execution.md`, `handoff.md` using the confirmed EARS requirements

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
