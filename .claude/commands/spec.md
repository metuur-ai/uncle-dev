---
description: Start spec-driven development — define an OpenSpec change before writing code
---

Invoke the agent-skills:spec-driven-development skill.

Begin by understanding what the user wants to build. First inspect `openspec/specs/` and any relevant open changes so the new change starts from current tracked truth.

Require a `<change-id>` for the work. If the user did not provide one, ask for it or propose one for approval.

Then use the OpenSpec CLI:

1. `openspec change create <change-id>`
2. `openspec artifact add <change-id> execution.md`
3. `openspec artifact add <change-id> handoff.md`

Ensure the active change contains `proposal.md`, `design.md`, `tasks.md`, `execution.md`, and `handoff.md`.

Ask clarifying questions about:
1. The objective and target users
2. Core features and acceptance criteria
3. Tech stack preferences and constraints
4. Known boundaries (what to always do, ask first about, and never do)

Then populate the shared OpenSpec artifacts:

- `proposal.md` for objective, problem framing, success criteria, scope, and boundaries
- `design.md` for architecture, constraints, commands, project structure, testing approach, and technical decisions
- `tasks.md` for shared story-level breakdown
- `execution.md` for shared sequencing and cross-story dependencies
- `handoff.md` for QA guidance and validation steps

Private technical substeps belong in `.devlocal/`, not in tracked shared artifacts.

Confirm the change contents with the user before proceeding.
