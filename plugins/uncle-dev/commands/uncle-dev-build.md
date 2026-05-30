---
description: Implement the next task incrementally — build, test, verify, commit
---

## Working Principles

1. **Think Before Coding** — Read the acceptance criteria and existing code before writing a single line. If the story is ambiguous, stop and clarify.
2. **Simplicity First** — Implement the minimum code to pass the test. Resist "while I'm here" improvements.
3. **Surgical Changes** — Touch only what the story requires. Don't refactor adjacent code, fix unrelated issues, or clean up pre-existing style.
4. **Goal-Driven Execution** — Write a failing test first. Success means test passes, build succeeds, no regressions, and the story is marked complete.

---

Invoke `uncle-dev-incremental-implementation` alongside `uncle-dev-test-driven-development`.

Resolve `preferences.sdd_mode` via `scripts/uncle-dev-config.sh` first (single source of truth).

If `sdd_mode=openspec`, use OpenSpec tasks as shared source of truth.
If `sdd_mode=lid-ears`, use `docs/tasks/` and LID/EARS docs as shared source of truth.

Pick the next pending shared story from the active mode's planning artifact. For each story:

0. Apply `uncle-dev-code-context` to identify all directories to be edited, read their `AGENTS.md` files, and validate architecture boundary compliance before writing code
1. Read the story's acceptance criteria and dependencies
2. Load relevant context such as existing code, patterns, and types
3. If useful, break the implementation into private technical steps in `.devlocal/<user>/<story-id>/scratchpad.md`
4. Write a failing test for the expected behavior (RED)
5. Implement the minimum code to pass the test (GREEN)
6. Run the full test suite to check for regressions
7. Run the build to verify compilation
8. Promote shared discoveries:
   - Update `execution.md` for blockers or cross-story dependencies
   - Update `tasks.md` for shared scope or task changes
   - Update `design.md` if implementation changes shared technical constraints
9. Commit with a descriptive message
10. Mark the story complete and move to the next one

If any step fails, follow `uncle-dev-debug-error`.
