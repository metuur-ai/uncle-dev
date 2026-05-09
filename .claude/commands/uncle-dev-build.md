---
description: Implement the next task incrementally — build, test, verify, commit
---

## Working Principles

1. **Think Before Coding** — Read the acceptance criteria and existing code before writing a single line. If the story is ambiguous, stop and clarify.
2. **Simplicity First** — Implement the minimum code to pass the test. Resist "while I'm here" improvements.
3. **Surgical Changes** — Touch only what the story requires. Don't refactor adjacent code, fix unrelated issues, or clean up pre-existing style.
4. **Goal-Driven Execution** — Write a failing test first. Success means: test passes, build succeeds, no regressions, story marked complete.

---

Invoke the agent-skills:uncle-dev-incremental-implementation skill alongside agent-skills:uncle-dev-test-driven-development.

**Step 0: Resolve the next task.** Invoke agent-skills:uncle-dev-next-task with `--claim` to:

- Detect the environment (OpenSpec CLI, `openspec/` dir, `.devlocal/` scratchpads, locks)
- Compute the parallel-safe ready set across all in-progress changes
- Surface any scratchpad/`tasks.md` conflict for the user to resolve before any code is written
- Recommend one story with a clear `why:` line, and acquire a lock for this agent
- If the user has already named a story, pass `--story <id>` to skip recommendation

If `uncle-dev-next-task` reports the ready set is empty (everything blocked) or there is no tracked work, stop and follow its guidance — do not invent work.

If `uncle-dev-next-task` reports `BLOCKED: pending acknowledgements`, do not proceed. Print the block message verbatim. The user must run `/uncle-dev-acknowledge ack <ids>` (or `reject` / `supersede` / hand-edit `openspec/acknowledge/<scope>.md`) and then re-invoke `/uncle-dev-build` before any code is written. This gate is **non-bypassable** — there is no flag to ignore pending acknowledgements.

For the chosen story:

0. Apply agent-skills:uncle-dev-code-context — identify all directories to be edited, read their `AGENTS.md` files, validate architecture boundary compliance before writing any code
1. Read the story's acceptance criteria and dependencies
2. Load relevant context (existing code, patterns, types)
3. If useful, break the implementation into private technical steps in `.devlocal/<user>/<story-id>/scratchpad.md`
4. Write a failing test for the expected behavior (RED)
5. Implement the minimum code to pass the test (GREEN)
6. Run the full test suite to check for regressions
7. Run the build to verify compilation
8. Promote shared discoveries:
   - Update `execution.md` for blockers or cross-story dependencies
   - Update `tasks.md` for shared scope/task changes
   - Update `design.md` if implementation changes shared technical constraints
9. Commit with a descriptive message
10. Mark the story complete and move to the next one

If any step fails, follow the agent-skills:uncle-dev-debug-error skill.
