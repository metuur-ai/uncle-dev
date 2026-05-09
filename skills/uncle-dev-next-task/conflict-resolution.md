# Conflict Resolution

When the personal `.devlocal/<user>/<story-id>/scratchpad.md` and the shared `openspec/changes/<change-id>/tasks.md` disagree, the picker halts and asks the user. **It never auto-resolves.**

## What Counts as a Conflict

A conflict exists when ALL of these are true:

1. A `.devlocal/<user>/<story-id>/scratchpad.md` file exists
2. The scratchpad has unchecked `- [ ]` items under a "Current step", "Next step", "Plan", or "TODO" heading
3. The corresponding story in `tasks.md` is marked **complete** (all acceptance criteria checked)
4. The scratchpad was modified within the last 7 days

The 7-day window prevents ancient scratchpads from blocking the picker forever. Older scratchpads are treated as archived (logged but not surfaced).

## What Does NOT Count

- Scratchpad with checked items (matches the `tasks.md` complete state — no conflict)
- Scratchpad for a story that no longer exists in `tasks.md` (story was renamed/deleted; surface as a separate warning, not a conflict)
- Scratchpad with no unchecked items under a "Current step" heading — only prose notes (the user just wrote design notes; not in-flight work)

## The Prompt

When a conflict is found, the skill outputs:

```
⚠ CONFLICT DETECTED

Story:       PF-001:1.3 Add config loader
Tasks.md:    marked complete (all 4 acceptance criteria checked)
             last modified: 2026-05-08 14:22 UTC (commit a3f2b1c)

Scratchpad:  .devlocal/javierhbr/1.3/scratchpad.md
             last modified: 2026-05-09 12:08 UTC (2h ago)
             3 unchecked steps under "Current step":
               - [ ] Verify env override behavior
               - [ ] Handle missing config file gracefully
               - [ ] Add fixture for malformed YAML

Choose:
  1. Resume 1.3
     → Uncheck the matching acceptance criteria in tasks.md
     → Drop the lock if held; re-claim for this agent
     → Continue from the scratchpad

  2. Discard scratchpad
     → Move .devlocal/javierhbr/1.3/scratchpad.md to .devlocal/_archive/
     → Trust tasks.md; treat 1.3 as complete
     → Pick the next ready story

  3. Open both for manual review
     → Print both files' relevant sections
     → Halt; let the user decide and re-run the picker

  4. Skip and pick a different story
     → Leave the conflict unresolved for now
     → Filter 1.3 from the ready set
     → Recommend the next-best ready story
```

The picker uses the platform's blocking question tool (`AskUserQuestion` in Claude Code, equivalent in other agents) to capture the choice. It does NOT proceed until the user answers.

## Each Outcome

### Outcome 1: Resume

1. For each unchecked acceptance criterion the user can identify, replace `- [x]` with `- [ ]` in `tasks.md`. (The picker doesn't guess which criteria need unchecking — it asks the user, or unchecks all of them as a safe default.)
2. Commit the un-check with message: `chore: reopen story 1.3 (resume from .devlocal scratchpad)`
3. If a lock exists for 1.3 owned by another agent, surface that as a secondary conflict — don't silently steal it.
4. If no lock exists, acquire one for the current agent.
5. Emit the standard handoff with `source: devlocal` and `scratchpad: <path> (resume)`.

### Outcome 2: Discard Scratchpad

1. Create `.devlocal/_archive/<user>/<story-id>-<timestamp>/` and move the scratchpad there. **Move, never delete** — the user might want it back.
2. Emit a confirmation: `archived to .devlocal/_archive/javierhbr/1.3-20260509-1340/`.
3. Re-run the ready-set computation now that the conflict is resolved.
4. Emit the standard handoff with the next recommendation.

### Outcome 3: Manual Review

1. Print the relevant sections of both files (last 30 lines of scratchpad, the story block from `tasks.md`).
2. Print the diff between scratchpad's "Current step" list and `tasks.md`'s acceptance criteria.
3. Exit cleanly with a non-zero status. The user inspects, edits whichever file is wrong, and re-runs the picker.

### Outcome 4: Skip

1. Add `1.3` to the in-memory "skipped this session" list (does not persist — re-running the picker re-surfaces the conflict).
2. Filter `1.3` from the ready set.
3. Recompute and emit the next recommendation.
4. The conflict will appear again next time the picker runs unless the user resolves it.

## Multi-Conflict Sessions

When more than one story has a conflict, present them one at a time, in document order. Don't batch — each conflict is its own decision and batching them invites careless "yes to all" choices.

## Conflict During Lock Acquisition

A subtler conflict: the picker recommends story 1.3, the caller goes to acquire the lock, and finds an existing lock owned by **the same agent name** but a different `session_id`. This usually means a previous session crashed mid-story.

In that case:

1. Read the existing lock's `started_at` and `last_heartbeat`
2. If heartbeat is fresh (< 1h) → another live session of the same agent has the lock; warn and pick a different story
3. If heartbeat is stale (> 4h) → offer to take over: print the previous session's last heartbeat and ask "take over the abandoned session?"
4. If somewhere between → ask the user explicitly

Take-over is allowed only with explicit user consent because the previous session may have made uncommitted changes that would be lost.

## Why Always Ask

The user chose "always ask" over auto-resolve in the design phase. The reasoning:

- `tasks.md` wins auto-resolution risks losing 30+ minutes of in-flight work in a scratchpad.
- Scratchpad wins auto-resolution risks re-opening a story someone else legitimately closed.
- Either default is wrong some of the time. The cost of a prompt is one keypress; the cost of a wrong auto-resolve is rework.

If the user later decides they want auto-resolve, they can pass `--conflict-policy=tasks-wins` or `--conflict-policy=scratchpad-wins` to the picker. The default stays `--conflict-policy=ask`.
