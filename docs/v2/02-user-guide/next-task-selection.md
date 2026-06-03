---
sidebar_position: 6
---

# uncle-dev-next-task — Summary

A new skill that answers one question every "continue working" command needs to ask: **what should I work on right now?** It picks the next ready task from OpenSpec changes and `.devlocal/` scratchpads, with parallelism, locks, and conflict prompts built in.

## Why This Exists

Before this skill, every "continue" command (`/uncle-dev-build continue`, `/uncle-dev-test`, `/uncle-dev-ship`) re-implemented the same logic inline:

1. Run `openspec list` to find the active change
2. Parse `tasks.md` to find unchecked stories
3. Pick the first one and start

Three problems:

- **Each command duplicates the parsing.** A bug in one place doesn't get fixed in the others.
- **The OpenSpec CLI has rough edges.** `openspec status` requires `--change`, errors on uppercase IDs, and the JSON output is partial. Every caller stumbles into these the same way.
- **No parallelism.** "First unchecked story" silently serializes work that could run in parallel — even when stories declare `Dependencies: None` and don't share files. Multiple agents (Conductor worktrees, parallel sessions) end up grabbing the same story.

The new skill solves all three by being the single source of truth for "what's next" and emitting a structured handoff that other commands consume.

## What It Does

Given the current state of `openspec/changes/<id>/tasks.md` files and `.devlocal/` scratchpads, the skill:

1. **Parses every in-progress change** in parallel and extracts story status, dependencies, mutex tags, and effort estimates.
2. **Detects conflicts** — when a `.devlocal` scratchpad has unchecked steps but `tasks.md` says the story is complete — and halts to ask the user. Always asks; never auto-resolves.
3. **Computes a ready set** of stories that are unblocked (deps satisfied, mutex available, no active locks held).
4. **Recommends one** with a deterministic tie-breaker so two agents calling at the same time agree on what's recommended.
5. **Optionally acquires a lock** so that when two agents race for the same story, exactly one wins and the other re-ranks.
6. **Emits a structured handoff** that `/uncle-dev-build` and friends parse instead of re-doing the work.

## How Parallelism Works

Two stories are **parallel-safe** when both:

- All their declared `(deps: ...)` are checked
- Their `(mutex: ...)` tags don't collide with any in-flight story's mutex

Mutex tags are project-defined strings (`schema`, `config`, `auth`, etc.) that name a shared resource. Two stories that both touch `db/migrations/` declare `(mutex: schema)` and the picker won't hand them out simultaneously, even though dependency-wise they're independent.

This unlocks two kinds of parallelism:

- **Within a change** — Story 1.3 (config loader) and Story 1.4 (logger middleware) both depend on 1.1 (schema migration). Once 1.1 is done, both 1.3 and 1.4 enter the ready set. Two agents can claim them. Story 1.5 (which depends on both) waits.
- **Across changes** — `auth-rework` and `dashboard-refactor` are completely independent. Their stories appear in the ready set together. An agent working on dashboard tokens never blocks an agent working on auth.

The picker is deterministic: same inputs → same recommendation. Two agents calling at the same instant compute the same ready set and the same #1 recommendation; they race only on lock acquisition, where exactly one wins. The loser re-ranks and picks #2.

## Worked Example

Imagine `tasks.md` has:

```
1.1 Schema migration       (deps: none)      (mutex: schema)   ✓ done
1.2 Seed data              (deps: 1.1)       (mutex: schema)   ✓ done
1.3 Config loader          (deps: 1.1)       (mutex: config)   pending
1.4 Logger middleware      (deps: 1.1)       (mutex: none)     pending
1.5 Wire config to logger  (deps: 1.3, 1.4)  (mutex: none)     pending
```

Plus a separate change `dashboard-refactor` with:

```
2.1 Theme tokens           (deps: none)      (mutex: none)     pending
```

**Agent A** calls `/uncle-dev-next-task`. Output:

```
READY SET (3 available, 3 parallel-safe, 1 blocked)
  recommended:  1.3 Config loader  [PF-001]   why: 1 story (1.5) blocked on this
  alternatives: 1.4 Logger middleware  [PF-001]
                2.1 Theme tokens         [dashboard-refactor]
  blocked:      1.5 ← waits on [1.3, 1.4]
```

Agent A picks 1.3 with `--claim`. Lock created. Mutex `config` is now held.

**Agent B** calls `/uncle-dev-next-task` ten seconds later. The picker sees:

```
READY SET (2 available, 2 parallel-safe, 1 blocked)
  recommended:  1.4 Logger middleware  [PF-001]  why: in-flight scratchpad none, smallest est
  alternatives: 2.1 Theme tokens         [dashboard-refactor]
  blocked:      1.5 ← waits on [1.3, 1.4]
```

`1.3` is no longer offered because A holds the lock. Mutex `config` doesn't block 1.4 or 2.1 since neither declares it. B picks 1.4. Both agents work in parallel without stepping on each other.

## How Conflicts Are Handled

When a `.devlocal/<user>/<story-id>/scratchpad.md` has unchecked steps but `tasks.md` says the story is complete, the picker halts and asks:

```
⚠ CONFLICT: PF-001:1.3
  tasks.md:    marked complete
  scratchpad:  3 unchecked steps, modified 2h ago

  Choose:
    1. Resume 1.3 — uncheck tasks.md, drop lock, continue from scratchpad
    2. Discard scratchpad — archive to .devlocal/_archive/, trust tasks.md
    3. Open both for manual review
    4. Skip and pick a different story
```

The user picks. The picker never auto-resolves. The reasoning: either default (tasks.md wins, scratchpad wins) is wrong some of the time, and the cost of asking is one keypress while the cost of a wrong auto-resolve is rework.

## Annotations You Add to tasks.md

For the picker to do anything beyond "first unchecked story", `tasks.md` needs annotations:

```markdown
### Story 1.3: Add config loader

**Acceptance criteria:**
- [ ] Loads YAML from path
- [ ] Validates schema

**Annotations:** (deps: 1.1) (mutex: config) (est: 45m)
```

Recognized keys: `deps`, `mutex`, `est`, `risk`, `agent`. Cross-change deps look like `(deps: dashboard-refactor:2.1, 1.2)`.

If a `tasks.md` has no annotations (legacy or quick-write), the picker falls back to **document order**: each story implicitly depends on the previous one. Conservative, but safe.

The companion skill `uncle-dev-spec-driven-development` should start emitting these annotations when generating new `tasks.md` files. Old files keep working.

## Lock File Format

When a story is claimed, `.devlocal/_locks/<change-id>/<story-id>.lock` is written:

```yaml
agent: claude-opus-4-7
worktree: feature/auth
session_id: 2026-05-09T14-32-00-abc123
started_at: 2026-05-09T14:32:00Z
last_heartbeat: 2026-05-09T14:45:12Z
pid: 48211
host: macbook-pro.local
```

- Acquired via atomic `mkdir` of a sentinel — race-safe on POSIX filesystems
- Heartbeat updated every ~5 minutes by the owning agent
- Stale (no heartbeat for > 4h) → surfaced in output, but never auto-released. The user runs `--release <story-id>` to free it.
- Released when the story is checked complete (orphaned locks are auto-cleaned)

In Conductor / multi-worktree setups, `.devlocal/_locks/` should be shared across worktrees (symlink or bind-mount). The picker warns if it detects worktree-local locks since that defeats the parallelism guard.

## Files Created

```
skills/uncle-dev-next-task/
  SKILL.md                       # main skill — process, output contract, rationalizations
  parsing-and-annotations.md     # tasks.md grammar, annotation keys, parser robustness
  parallelism-and-locks.md       # ready-set algorithm, lock format, atomic acquisition
  conflict-resolution.md         # the 4-option prompt, multi-conflict sessions

.claude/commands/
  uncle-dev-next-task.md         # slash command wrapper, supports --story / --ready / --release / --claim

docs/
  uncle-dev-next-task-summary.md # this file
```

## How `/uncle-dev-build continue` Changed

**Before:**

```
1. Check openspec --version
2. openspec list to find the active change   ← no idea what to do with multiple
3. openspec show <id>                         ← arg-shape varies
4. Parse tasks.md inline                      ← duplicate logic
5. Pick first unchecked story                 ← ignores deps and mutexes
6. Start coding
```

**After:**

```
1. Invoke uncle-dev-next-task --claim
2. Use the recommendation (or follow conflict prompt if surfaced)
3. Start coding
```

The CLI quirks, parser logic, dep resolution, mutex checks, lock acquisition, and conflict prompts all live in one skill. Every command that picks tasks gets the upgrade for free.

## How Other Commands Should Adopt It

| Command | Adoption |
|---|---|
| `/uncle-dev-build` | ✅ updated — calls `uncle-dev-next-task --claim` first |
| `/uncle-dev-test` | Should call `uncle-dev-next-task` (no claim) to find a story to write tests for |
| `/uncle-dev-ship` | Should call `uncle-dev-next-task --ready` to verify nothing is unchecked before shipping |
| `/uncle-dev-review` | Should call `uncle-dev-next-task --story <id>` to scope the review to a specific story's diff |
| `/uncle-dev-spec` | Should emit `(deps: ...)` and `(mutex: ...)` annotations when generating new `tasks.md` |

These edits aren't done yet — only `/uncle-dev-build` was updated as part of this change. Adopting from the others is mechanical and additive.

## What's Intentionally Not Done

- **No execution logic.** The skill picks the task; it doesn't write code, run tests, or commit. That's `/uncle-dev-build`'s job.
- **No automatic conflict resolution.** Per design choice: always ask.
- **No persistence of "skipped this session."** If you skip a conflicted story, it'll appear again on the next run. Forces you to actually deal with it.
- **No web UI / dashboard.** The picker is a CLI/skill, not a service. The lock files are human-readable YAML for when you need to inspect them.

## What Could Go Wrong

| Scenario | Mitigation |
|---|---|
| Two agents in two worktrees pick the same story | Lock files in shared `.devlocal/_locks/` (symlink/bind-mount). The picker warns if it detects worktree-local locks. |
| Stale lock from a crashed session | Heartbeat staleness check + manual `--release`. Never auto-release. |
| Annotation typo (e.g., `(dpes: 1.1)`) | Parser surfaces a per-story warning; story drops out of ready set rather than silently using defaults. |
| `tasks.md` and scratchpad disagree | Halt + 4-option prompt. Always ask. |
| Cross-change dep refers to a deleted change | Surface as unsatisfiable; don't silently treat as satisfied. |
| Two stories tie on every tie-breaker | Final tie-break by `change-id` then `story-id` alphabetic, so ranking is fully deterministic. |

## Next Steps

1. Run `scripts/install-claude.sh` to register the new skill and command in `~/.claude/plugins/`.
2. Try it: `/uncle-dev-next-task --ready` in a project with an OpenSpec change.
3. Add `(deps: ...)` and `(mutex: ...)` annotations to your active `tasks.md` to start unlocking parallelism. Without annotations, the picker falls back to document order — still works, just serial.
4. If using Conductor or multiple worktrees, set up the `.devlocal/_locks/` symlink so locks are shared across worktrees.
