---
description: Break work into small verifiable tasks with acceptance criteria and dependency ordering
---

## Working Principles

1. **Think Before Coding** — Read the full spec (`proposal.md`, `design.md`) before writing a single task. Understand the dependency graph before ordering anything.
2. **Simplicity First** — Tasks should be the minimum slices that deliver value. Don't decompose into exhaustive subtasks or predict work that isn't confirmed.
3. **Surgical Changes** — Write only what belongs in `tasks.md` and `execution.md`. Private technical notes go in `.devlocal/`, not in shared artifacts.
4. **Goal-Driven Execution** — Every task must have explicit acceptance criteria and a verification step. A plan without checkpoints is incomplete.

---

Invoke the agent-skills:planning-and-task-breakdown skill.

Read the active OpenSpec change's `proposal.md` and `design.md`, plus the relevant codebase sections. Then:

1. Enter plan mode — read only, no code changes
2. Identify the dependency graph between components
3. Slice work into shared story-level items, not code-level subtasks
4. Write shared stories with acceptance criteria and verification steps into `tasks.md`
5. Record cross-story ordering, blockers, and coordination notes in `execution.md`
6. Keep private technical breakdown in `.devlocal/<user>/<story-id>/scratchpad.md`
7. Present the plan for human review

Do not write `tasks/plan.md` or `tasks/todo.md`. The tracked outputs are `openspec/changes/<change-id>/tasks.md` and `openspec/changes/<change-id>/execution.md`.
