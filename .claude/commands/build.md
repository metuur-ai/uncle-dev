---
description: Implement the next task incrementally — build, test, verify, commit
---

Invoke the agent-skills:incremental-implementation skill alongside agent-skills:test-driven-development.

Pick the next pending shared story from the active change's `tasks.md`. For each story:

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

If any step fails, follow the agent-skills:debugging-and-error-recovery skill.
