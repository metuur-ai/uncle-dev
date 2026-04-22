# Research: How an OpenSpec Change and Task Is Flagged as Completed/Done

**Date:** 2026-04-22  
**Question:** How is an OpenSpec change and task flagged as completed or done?

---

## Summary

There is no `status:` field, no `openspec change close` command, and no automated done-flag. "Done" is expressed entirely through **markdown checkboxes** in two artifact files (`tasks.md`, `execution.md`), validated by human review at phase gates, and formally closed by **reconciling the change folder into `openspec/specs/`** at ship time.

---

## Two Scopes of Tracking

| Scope | Location | Lifetime |
|---|---|---|
| Shared truth | `openspec/changes/<change-id>/tasks.md` + `execution.md` | Lives until reconciled into `openspec/specs/` |
| Agent's private substeps | `.devlocal/scratchpads/` or `.devlocal/executions.md` | Disposable after merge |

---

## Level 1 — Story/Task Done (inside `tasks.md`)

Every story in `tasks.md` uses markdown checkboxes as the done signal. The planning skill defines the required shape:

```markdown
## Story [ID]: [Short descriptive title]

**Acceptance criteria:**
- [ ] [Specific, testable condition]

**Verification:**
- [ ] Tests pass: `npm test -- --grep "feature-name"`
- [ ] Build succeeds: `npm run build`
- [ ] Manual check: [description of what to verify]
```

The agent ticks boxes (`- [x]`) as it completes each criterion during the build loop.

**Sources:**
- [skills/uncle-dev-planning-and-task-breakdown/SKILL.md](../../skills/uncle-dev-planning-and-task-breakdown/SKILL.md) lines 86–101 — story template
- [.claude/commands/uncle-dev-build.md](../../.claude/commands/uncle-dev-build.md) line 10 — "Success means: test passes, build succeeds, no regressions, story marked complete."
- [.claude/commands/uncle-dev-build.md](../../.claude/commands/uncle-dev-build.md) line 31 — "10. Mark the story complete and move to the next one"
- [skills/uncle-dev-using-agent-skills/SKILL.md](../../skills/uncle-dev-using-agent-skills/SKILL.md) line 109 — "A task is not complete until verification passes."

---

## Level 2 — Phase Checkpoint Done (inside `execution.md`)

`execution.md` tracks cross-story sequencing, blockers, and phase checkpoints using the same checkbox pattern:

```markdown
## Checkpoint: After Stories 101-103
- [ ] All tests pass
- [ ] Application builds without errors
- [ ] Core user flow works end-to-end
- [ ] Review with human before proceeding
```

Checkpoints pass when all boxes in the block are ticked and a human approves the gate.

**Source:**
- [skills/uncle-dev-planning-and-task-breakdown/SKILL.md](../../skills/uncle-dev-planning-and-task-breakdown/SKILL.md) lines 105–139

---

## Level 3 — Agent Private Substeps (`.devlocal/`)

During `/uncle-dev-build`, the agent writes and ticks granular checklists in `.devlocal/scratchpads/` or `.devlocal/executions.md`. These are not shared truth.

**Source:**
- [docs/04-devlocal-directory.md](../../docs/04-devlocal-directory.md) line 16 — "Once the task is complete, this temporary checklist becomes obsolete and can be safely ignored or deleted."

---

## Level 4 — Change Lifecycle Done (the formal close)

A change is formally complete when its artifacts are **reconciled back into `openspec/specs/`**. This happens during the Ship phase (`/uncle-dev-ship`).

The canonical ship prompt (triggered by the human saying "The feature is complete"):

> "Reconcile our updates from the change artifact back into the main `openspec/specs/` directory to update our core documentation, and write a detailed commit message."

**Sources:**
- [docs/03-sdd-and-openspec.md](../../docs/03-sdd-and-openspec.md) line 34 — "Once a feature is successfully implemented via the `tasks.md` checklist, the new updates from the change folder are reconciled back into the main `openspec/specs/` folder."
- [docs/05-idea-to-deploy-flow.md](../../docs/05-idea-to-deploy-flow.md) line 33 — "The agent updates main `openspec/specs/` to reconcile the changes..."
- [docs/06-prompts-by-phase.md](../../docs/06-prompts-by-phase.md) line 39 — canonical ship prompt
- [skills/uncle-dev-spec-driven-development/SKILL.md](../../skills/uncle-dev-spec-driven-development/SKILL.md) line 188 — "Reconcile approved truth back into `openspec/specs/`"

---

## Structural Guard (not a done-flag, but a gate)

The `openspec-guard.sh` hook fires on every `Edit`/`Write` inside `openspec/changes/*/`. It verifies that all 5 required artifacts exist (`proposal.md`, `design.md`, `tasks.md`, `execution.md`, `handoff.md`). Missing artifacts emit an `INFO` message but do not block (exit 0). This is a structural completeness check, not a done/undone state tracker.

**Source:**
- [hooks/openspec-guard.sh](../../hooks/openspec-guard.sh) lines 32–36

---

## Complete Picture

```
Story acceptance criteria ticked (tasks.md)
  ↓
Phase checkpoint ticked (execution.md)
  ↓
Human says "The feature is complete" → triggers /uncle-dev-ship
  ↓
Pre-launch checklist passes (tests, security, perf, docs)
  ↓
Change folder reconciled into openspec/specs/   ← formal done
```

No status enum. No CLI close command. Done = all checkboxes checked + specs reconciled.
