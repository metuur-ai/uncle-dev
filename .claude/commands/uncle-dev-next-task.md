---
description: Pick the next ready task from OpenSpec changes and .devlocal scratchpads, with parallelism and lock awareness
---

Invoke the agent-skills:uncle-dev-next-task skill.

## Arguments

- `(no args)` — full resolution: detect environment, compute ready set, emit recommendation
- `--ready` — print the ready set only (all parallel-safe stories), no single recommendation
- `--story <id>` — explicit pick; skip resolution and emit handoff for that story (validates it exists and is ready)
- `--change <id>` — restrict resolution to one change instead of all in-progress changes
- `--release <story-id>` — release a stale lock and exit
- `--claim` — acquire a lock on the recommended story (default for `/uncle-dev-build continue`; off for preview)
- `--conflict-policy <ask|tasks-wins|scratchpad-wins>` — default `ask`

## Process

1. Run the environment detection (openspec CLI? `openspec/`? `.devlocal/`? existing locks?)
2. Load all in-progress changes and parse `tasks.md` per `parsing-and-annotations.md`
3. Run the conflict check per `conflict-resolution.md` — if any conflict, prompt the user and halt until resolved
4. Compute the ready set per `parallelism-and-locks.md`
5. Rank by tie-breakers: most-descendants → resumes-scratchpad → smallest-est → doc-order → change-id
6. Emit the handoff in the standard format
7. Acquire a lock only if `--claim` is passed

## Output

Print the structured handoff exactly as defined in the skill's "Output" section. Callers (`/uncle-dev-build`, `/uncle-dev-test`, `/uncle-dev-ship`) parse this format.

## Failure Modes

- No `openspec/` directory and no `.devlocal/` scratchpads → exit cleanly: "no tracked work; suggest `/uncle-dev-spec`"
- All changes complete → exit cleanly: "all changes shipped; suggest `/uncle-dev-knowledge-capture`"
- Ready set is empty but unchecked stories exist → diagnostic mode: print the blocked list with reasons
- Conflict detected → halt with the prompt; do not pick a story until resolved
- Multiple stale locks (> 4h) → list them and suggest `--release` for each
- Pending acknowledgements for scopes the recommended story touches → halt with the `BLOCKED:` block from `acknowledge-gate.md`; do not pick a story or acquire a lock. The user must run `/uncle-dev-acknowledge ack <ids>` (or reject/supersede) before re-running.
