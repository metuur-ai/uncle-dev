---
description: Pick the next ready task — from docs/tasks/ in lid-ears mode, or from OpenSpec changes in openspec mode
---

## Step 0 — Read SDD mode (do this first)

```bash
CONFIG_LOOKUP="${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev-agent-skills/1.0.0/scripts/uncle-dev-config.sh"
SDD_MODE=$(bash "${CONFIG_LOOKUP}" preferences.sdd_mode openspec 2>/dev/null)
echo "${SDD_MODE}"
```

**Route based on result — pick exactly one path:**

---

## Path A — `lid-ears` mode

**If sdd_mode is `lid-ears`: follow this path. Do NOT invoke the agent-skills:uncle-dev-next-task skill.**

Work items live in `docs/tasks/<slug>.md` (produced by `/uncle-dev-plan`).

Resolution process:

1. `ls docs/tasks/*.md` — find all task files; if none exist, exit: "no task files found; run `/uncle-dev-plan` first."
2. Parse each file for unchecked items: `- [ ] <id> <title>`
3. Respect `(deps: x, y)` — a story is ready only if all declared deps are checked
4. Respect `(mutex: tag)` — drop stories whose mutex is held by another in-flight story
5. Check `.devlocal/_locks/` for active locks — drop stories with an active lock
6. Rank the ready set: most-descendants → resumes-scratchpad → smallest-est → document-order
7. Emit the handoff:

```
READY SET (N available)
  ┌─ recommended
  │  source:     lid-ears
  │  file:       docs/tasks/<slug>.md:<line>
  │  story:      <id> <title>
  │  deps:       [<checked deps>]
  │  est:        ~Xm
  │  why:        <tie-breaker reason>
  │  scratchpad: .devlocal/<user>/<story-id>/scratchpad.md
  │
  ├─ parallel-safe alternatives
  │  • <id> <title>   [<slug>]
  │
  └─ blocked
     • <id> <title> ← waits on [<deps>]

NEXT ACTION: pick recommended, or pass --story <id> to override.
```

8. Acquire `.devlocal/_locks/<slug>/<story-id>.lock` only if `--claim` is passed

**Failure modes:**
- No `docs/tasks/` or all files empty → exit: "no task files found; run `/uncle-dev-plan` first."
- All stories checked → exit: "all tasks complete; run `/uncle-dev-ship`."
- Ready set empty but unchecked stories exist → list each with its blocking dep(s)

**Arguments work the same as openspec mode:**
- `(no args)` — full resolution, emit recommendation
- `--ready` — print ready set only, no single recommendation
- `--story <id>` — explicit pick, skip resolution
- `--release <story-id>` — release a stale lock and exit
- `--claim` — acquire a lock on the recommended story

---

## Path B — `openspec` mode (default)

**If sdd_mode is `openspec` or missing: follow this path.**

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
