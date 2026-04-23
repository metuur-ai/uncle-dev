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

Check if the OpenSpec CLI is available (`openspec --version`). When available:

- `openspec list` to find the active change
- `openspec show <change-id>` to read the change and its tasks
- `openspec status <change-id>` to check which artifacts are complete

If not installed, recommend `npm install -g openspec` and read files directly.

Pick the next pending shared story from the active change's `tasks.md`. For each story:

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
