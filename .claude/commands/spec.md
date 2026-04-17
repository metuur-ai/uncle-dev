---
description: Start spec-driven development — define an OpenSpec change before writing code
---

## Working Principles

1. **Think Before Coding** — Ask clarifying questions before writing any artifact. Surface ambiguities in the problem, not the solution.
2. **Simplicity First** — Spec only what this change needs. Don't design future features or add scope that wasn't requested.
3. **Surgical Changes** — Each OpenSpec artifact has a distinct purpose. Don't duplicate content between `proposal.md`, `design.md`, and `tasks.md`.
4. **Goal-Driven Execution** — Success means the user has reviewed and approved the spec before any code is written.

---

Invoke the agent-skills:spec-driven-development skill.

Begin by understanding what the user wants to build. First inspect `openspec/specs/` and any relevant open changes so the new change starts from current tracked truth.

Require a `<change-id>` for the work. Derive the next sequential ID as follows:

1. Scan `openspec/changes/` for directories matching `NNN-*` (three-digit prefix)
2. Extract the highest `NNN` found; next number = highest + 1 (use `001` if none exist)
3. Propose the next ID to the user: `"Next change ID: 003-<descriptive-slug> — enter a slug or accept"`
4. Validate any user-provided ID against the pattern `^\d{3}-.+`; reject and re-prompt if it does not match (e.g., reject `my-feature`, accept `003-my-feature`)

Then use the OpenSpec CLI:

1. `openspec change create <validated-change-id>`
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
