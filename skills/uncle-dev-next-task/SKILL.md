---
name: uncle-dev-next-task
description: Picks the next actionable task — from docs/tasks/ in lid-ears mode, or from OpenSpec changes in openspec mode. Computes a parallel-safe ready set and surfaces conflicts. Use when starting or resuming work, when the user asks "what's next", when `/uncle-dev-build continue` runs, or when multiple agents need to coordinate on which story to pick.
---
## Overview

Resolve the question "what should I work on right now?" deterministically. Routes to the correct task source based on `sdd_mode`:
- `lid-ears`: picks from `docs/tasks/<slug>.md` files (produced by `/uncle-dev-plan`)
- `openspec`: picks from OpenSpec change `tasks.md` files and `.devlocal/` scratchpads

This skill is a coordinator, not an implementer. It returns a structured handoff that `/uncle-dev-build`, `/uncle-dev-test`, `/uncle-dev-review`, and `/uncle-dev-ship` consume.

## Inputs and Outputs

Inputs (all optional):
- `--story <id>` — explicit pick, skip resolution
- `--change <id>` — restrict to one change
- `--ready` — print the ready set only, no recommendation
- `--release <story-id>` — release a stale lock and exit

Output (the handoff contract):

```
READY SET (3 available, 2 parallel-safe, 1 blocked)
  ┌─ recommended
  │  source:     openspec
  │  change:     001-foundations-cross-cutting
  │  story:      1.3 Add config loader
  │  file:       openspec/changes/001-foundations-cross-cutting/tasks.md:42
  │  deps:       [1.1 ✓, 1.2 ✓]
  │  mutex:      none
  │  est:        ~45m
  │  why:        longest dependency chain ahead (4 stories block on it)
  │  scratchpad: .devlocal/javierhbr/1.3/scratchpad.md (will create)
  │
  ├─ parallel-safe alternatives
  │  • 1.4 Logger middleware    [001-foundations-cross-cutting]  mutex: none
  │  • 2.1 Theme tokens         [dashboard-refactor]  mutex: none
  │
  └─ blocked
     • 1.5 Wire config to logger ← waits on [1.3, 1.4]
     • 1.6 Audit log sink        ← waits on [1.4]

NEXT ACTION: pick recommended, or pass --story <id> to override.
```

If a conflict is detected, output is replaced by the conflict prompt — see `conflict-resolution.md`.

If the recommended story is blocked by pending acknowledgements (see `acknowledge-gate.md`), the output above is replaced by:

```
BLOCKED: pending acknowledgements for scopes touched by 1.3 [api, share]
  • D5 (api) — constant-time login            openspec/acknowledge/api.md:14
  • D9 (api, share) — passwordHash nullable   openspec/acknowledge/api.md:48

Other stories in the ready set are also affected:
  • 1.4 [api]      blocked by D5, D6
  • 2.1 [share]    blocked by D9

To unblock:
  /uncle-dev-acknowledge ack D5,D9               # mark acknowledged
  /uncle-dev-acknowledge reject D5 --reason "…"  # reject + record
  Edit openspec/acknowledge/<scope>.md and flip `status:` manually

This gate is non-bypassable. After unblocking, re-run /uncle-dev-next-task.
```

Callers (`/uncle-dev-build`, `/uncle-dev-test`, etc.) MUST surface this output verbatim and stop — they do not get to claim a story while the gate fires.

## The Resolution Process

### Phase 0 — Read SDD mode (ALWAYS first)

Run this before any other step. The result determines which path to follow.

```bash
_scripts="${CLAUDE_PLUGIN_ROOT:-}/scripts"
[[ ! -f "$_scripts/uncle-dev-detect-mode.sh" ]] && \
  _scripts="$(ls -1d "${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/"*/ 2>/dev/null | sort -V | tail -1)scripts"
SDD_MODE=$(bash "$_scripts/uncle-dev-detect-mode.sh")
# For mode semantics see scripts/uncle-dev-detect-mode.sh
# If the script is unavailable, default to lid-ears (R-5.6)
SDD_MODE="${SDD_MODE:-lid-ears}"
echo "$SDD_MODE"
```

| Result | Path |
|--------|------|
| `lid-ears` | Follow Path A — LID-EARS below. Never check for `openspec/`. |
| `openspec` | Follow Path B — OpenSpec below. |
| (empty / unavailable) | Follow Path A — default is `lid-ears` (R-5.6). |

---

<!-- UNCLE_DEV:BRANCH:lid-ears:START -->
### Path A — LID-EARS Resolution

Only when `sdd_mode: lid-ears`. Do NOT run any openspec command.

```
   ┌─────────────────────────────────────────────────┐
   │ 1. Find task files                              │
   │    - ls docs/tasks/*.md                         │
   │    - If none exist → exit: "no task files;      │
   │      run /uncle-dev-plan first"                 │
   └─────────────────────────────────────────────────┘
                          │
                          ▼
   ┌─────────────────────────────────────────────────┐
   │ 2. Parse unchecked items                        │
   │    - Find all "- [ ] <id> <title>" lines        │
   │    - Extract (deps:), (mutex:), (est:)          │
   └─────────────────────────────────────────────────┘
                          │
                          ▼
   ┌─────────────────────────────────────────────────┐
   │ 3. Compute ready set                            │
   │    - Drop stories with unsatisfied deps         │
   │    - Drop stories whose mutex is held           │
   │    - Drop stories with active locks in          │
   │      .devlocal/_locks/<slug>/<story-id>.lock    │
   └─────────────────────────────────────────────────┘
                          │
                          ▼
   ┌─────────────────────────────────────────────────┐
   │ 4. Rank and recommend                           │
   │    Tie-breakers:                                │
   │    a) Most descendants (unblocks most)          │
   │    b) Resumes in-flight scratchpad              │
   │    c) Smallest est                              │
   │    d) Document order                            │
   └─────────────────────────────────────────────────┘
                          │
                          ▼
   ┌─────────────────────────────────────────────────┐
   │ 5. Emit handoff and (optionally) acquire lock   │
   └─────────────────────────────────────────────────┘
```

Handoff format (lid-ears):
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
  │  • <id> <title>
  │
  └─ blocked
     • <id> <title> ← waits on [<deps>]

NEXT ACTION: pick recommended, or pass --story <id> to override.
```

Failure modes (lid-ears):
- No `docs/tasks/` directory or all files empty → exit: "no task files found; run `/uncle-dev-plan` first."
- All stories checked → exit: "all tasks complete; run `/uncle-dev-ship`."
- Ready set empty but unchecked stories exist → list each with its blocking dep(s)
<!-- UNCLE_DEV:BRANCH:lid-ears:END -->

---

<!-- UNCLE_DEV:BRANCH:openspec:START -->
### Path B — OpenSpec Resolution

Only when `sdd_mode: openspec`.

```
   ┌─────────────────────────────────────────────────┐
   │ 1. Detect environment                           │
   │    - openspec CLI?  openspec/ dir?              │
   │    - .devlocal/ scratchpads?                    │
   │    - existing locks in .devlocal/_locks/?       │
   └─────────────────────────────────────────────────┘
                          │
                          ▼
   ┌─────────────────────────────────────────────────┐
   │ 2. Load all in-progress changes                 │
   │    - Parse each tasks.md (see parsing-and-      │
   │      annotations.md)                            │
   │    - Extract deps, mutex tags, estimates        │
   └─────────────────────────────────────────────────┘
                          │
                          ▼
   ┌─────────────────────────────────────────────────┐
   │ 3. Check for scratchpad/tasks.md conflicts      │
   │    - If conflict → conflict-resolution.md       │
   │      flow, ASK USER, halt until resolved        │
   └─────────────────────────────────────────────────┘
                          │
                          ▼
   ┌─────────────────────────────────────────────────┐
   │ 4. Compute ready set                            │
   │    (see parallelism-and-locks.md)               │
   │    - Filter unchecked stories                   │
   │    - Drop ones with unsatisfied deps            │
   │    - Drop ones whose mutex is held              │
   │    - Drop ones with active locks                │
   └─────────────────────────────────────────────────┘
                          │
                          ▼
   ┌─────────────────────────────────────────────────┐
   │ 4b. Apply acknowledge gate                      │
   │     (see acknowledge-gate.md)                   │
   │     - Derive each story's touched scopes        │
   │     - Drop stories blocked by pending           │
   │       decisions in openspec/acknowledge/        │
   │     - Non-bypassable: no flag overrides this    │
   └─────────────────────────────────────────────────┘
                          │
                          ▼
   ┌─────────────────────────────────────────────────┐
   │ 5. Rank and recommend                           │
   │    Tie-breakers, in order:                      │
   │    a) Has the most descendants (unblocks most)  │
   │    b) Resumes an in-flight scratchpad           │
   │    c) Smallest est (quick wins finish first)    │
   │    d) Earliest in tasks.md document order       │
   └─────────────────────────────────────────────────┘
                          │
                          ▼
   ┌─────────────────────────────────────────────────┐
   │ 6. Emit handoff and (optionally) acquire lock   │
   │    - Lock acquired only when caller says        │
   │      "I'm starting this now" — not on dry-run   │
   └─────────────────────────────────────────────────┘
```

### Step 1: Detect Environment

Run these checks in parallel:

```bash
openspec --version 2>/dev/null && echo "cli: yes" || echo "cli: no"
[ -d openspec ] && echo "spec-dir: yes" || echo "spec-dir: no"
[ -d .devlocal ] && echo "devlocal: yes" || echo "devlocal: no"
[ -d .devlocal/_locks ] && ls .devlocal/_locks/ 2>/dev/null
```

Decision:
- CLI + spec-dir → use CLI for change discovery, files for tasks parsing
- No CLI but spec-dir → recommend `npm install -g openspec`, fall back to file reads
- No spec-dir but devlocal → scratchpad-only mode (rare; usually means the spec was deleted)
- Neither → exit cleanly: "no tracked work; suggest `/uncle-dev-spec`"

### Step 2: Load In-Progress Changes

When CLI is available:

```bash
openspec list --json 2>/dev/null
```

Filter changes whose status is NOT `complete`. For each, parse `openspec/changes/<id>/tasks.md` per the grammar in `parsing-and-annotations.md`.

When CLI is unavailable, walk `openspec/changes/*/` and treat any change with at least one unchecked `- [ ]` in `tasks.md` as in-progress.

### Step 3: Conflict Check

For each scratchpad in `.devlocal/<user>/<story-id>/scratchpad.md`:

- Find the matching story in `tasks.md`
- If the story is checked but the scratchpad has unchecked steps modified within the last 7 days → conflict

When a conflict is found, halt and follow `conflict-resolution.md`. Always ask the user — never auto-resolve.

### Step 4: Compute the Ready Set

See `parallelism-and-locks.md` for the algorithm. In summary, a story enters the ready set when:

1. It is unchecked in `tasks.md`
2. All its declared `(deps: a, b)` are checked
3. Its `(mutex: tag)` is not held by another in-flight story
4. No active lock exists in `.devlocal/_locks/<change-id>/<story-id>.lock`

Stories from different changes are parallel-safe by default, unless their `proposal.md` frontmatter declares a shared `mutex:`.

### Step 4b: Apply the Acknowledge Gate

See `acknowledge-gate.md` for the full algorithm. After Step 4, every story still in the ready set is checked against `openspec/acknowledge/`:

1. Derive the story's touched scopes — the `(scope: a, b)` annotation, plus any `apps/<x>/` or `packages/<x>/` path mentions in the story block, plus any scopes named in the story's `design.md` Technical Decisions rows.
2. If any `<scope>.md` file under `openspec/acknowledge/` has a `### D<N>` section with `status: pending` whose scope is in the story's touched scopes, drop the story to a new blocked-by-acknowledgement bucket and record each blocking D-id.
3. Whenever the recommendation would have been a blocked-by-acknowledgement story, the picker emits the `BLOCKED:` output (see the output contract above) instead of the standard `READY SET` block. `--claim` MUST refuse to acquire a lock in this case.

The gate is non-bypassable — there is no `--ignore-acknowledgements` flag. To unblock: ack, reject, or supersede the pending decisions via `/uncle-dev-acknowledge`.

If `openspec/acknowledge/` does not exist (the project hasn't started using ack notes yet), Step 4b is a no-op.

### Step 5: Rank

The recommended pick uses these tie-breakers in order:

1. Most descendants — picking this unblocks the most downstream work
2. Resumes a scratchpad — finish what was started (only if no conflict)
3. Smallest estimate — small wins build momentum and free up locks
4. Document order — first unchecked in `tasks.md`

If two stories tie on all four, pick the one whose change-id sorts first alphabetically. Determinism matters when multiple agents call this skill at once.

### Step 6: Emit and Optionally Lock

By default, the skill emits the handoff but does NOT acquire a lock. Locks are acquired only when the caller passes `--claim` or when invoked from a "start now" command like `/uncle-dev-build continue`. This keeps `--ready` and `--story <id>` (preview) calls side-effect-free.

When claiming, write `.devlocal/_locks/<change-id>/<story-id>.lock` with agent id, timestamp, and pid (see `parallelism-and-locks.md`).
<!-- UNCLE_DEV:BRANCH:openspec:END -->

## Working with Multiple Agents in Parallel

When two agents (or two worktrees, or two sessions) call this skill at the same time:

1. They both compute the same ready set deterministically
2. They both rank by the same tie-breakers, so they arrive at the same recommendation
3. The first to acquire the lock on the recommended story wins it
4. The second sees the lock, drops that story from its ready set, and re-ranks

This works because:
- Lock acquisition is atomic (file create with `O_EXCL` semantics — `mkdir`-style)
- The ranking function is pure and deterministic
- Mutex tags prevent two agents from picking stories that touch the same shared resource even if both stories are technically unblocked

For Conductor-style worktree workflows, the lock file lives in the shared repo (not the worktree) so it's visible across worktrees. By convention, `.devlocal/_locks/` is gitignored but symlinked or bind-mounted across worktrees in Conductor setups.

See `parallelism-and-locks.md` for the full mechanics, including stale-lock recovery.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just pick the first unchecked story in tasks.md" | That ignores deps. You'll start something blocked, hit the wall, and have to back out. The ready-set check is cheap. |
| "There's only one agent, locks are pointless" | Until tomorrow, when you open a second worktree to keep working while a long test runs. Cost of locks: one file per story. Cost of double-claiming: lost work. |
| "The scratchpad and tasks.md will never disagree" | They will. Someone amends a commit, someone resolves a conflict, someone uses `--squash`. The conflict prompt is cheap insurance. |
| "I don't need mutex tags, deps cover it" | Deps are for "X must finish before Y starts." Mutex is for "X and Y both modify schema.sql, so they can't run at the same time even though neither blocks the other." Different problem, different tool. |
| "I'll just fix tasks.md by hand when I disagree" | That works once. Across three agents and five sessions, hand-fixes drift. Encode the rule (deps/mutex) once. |

## Red Flags

- Two agents picked the same story → lock mechanism failed; check `.devlocal/_locks/` permissions
- Story marked complete in `tasks.md` but scratchpad has 5 unchecked steps → conflict was suppressed; check why
- Ready set is empty but unchecked stories exist → all stories blocked; investigate dep/mutex declarations
- Recommendation flips between two stories on identical state → tie-breaker is non-deterministic; bug
- Stale lock older than 4h → previous agent died; offer to release with `--release <story-id>`
- A change is marked Complete by `openspec list` but `tasks.md` has unchecked items → trust the file, not the CLI summary

## Verification

Before handing off to the caller, confirm:

- [ ] Environment detection completed (CLI? spec-dir? devlocal?)
- [ ] All in-progress changes parsed; parse errors surfaced, not swallowed
- [ ] No unresolved scratchpad/tasks.md conflicts
- [ ] Ready set computed with deterministic ranking
- [ ] Recommendation includes a `why:` line citing the tie-breaker that won
- [ ] Lock acquired (if `--claim`) or skipped (if dry-run/preview)
- [ ] Handoff output matches the contract above so callers can parse it

## Related Skills and Files

- `parsing-and-annotations.md` — `tasks.md` grammar, `deps:` / `mutex:` / `est:` annotations
- `parallelism-and-locks.md` — ready-set algorithm, lock file format, stale-lock recovery
- `conflict-resolution.md` — the three-way prompt when scratchpad and tasks.md disagree
- `uncle-dev-spec-driven-development` — emits the annotations this skill consumes
- `uncle-dev-planning-and-task-breakdown` — produces the `tasks.md` files
- `uncle-dev-incremental-implementation` — the typical caller via `/uncle-dev-build`
