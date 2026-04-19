---
description: Simplify code for clarity and maintainability — reduce complexity without changing behavior
---

## Working Principles

1. **Think Before Coding** — Understand the code's purpose, callers, and edge cases before touching it. Never simplify what you don't fully understand.
2. **Simplicity First** — Simplify toward clarity, not cleverness. A longer readable function beats a terse cryptic one.
3. **Surgical Changes** — Only simplify code in the specified scope. Don't fix adjacent issues you notice along the way.
4. **Goal-Driven Execution** — Success means all tests still pass, the diff is smaller, and the code reads more easily than before.

---

Invoke `uncle-dev-dev-code-simplification`.

Simplify recently changed code, or the specified scope, while preserving exact behavior:

1. Read `AGENTS.md` and any adjacent rules files for project conventions
2. Identify the target code, defaulting to recent changes unless a broader scope is specified
3. Understand the code's purpose, callers, edge cases, and test coverage before changing it
4. Scan for simplification opportunities:
   - Deep nesting to guard clauses or extracted helpers
   - Long functions to smaller single-purpose units
   - Nested ternaries to clearer control flow
   - Generic names to descriptive names
   - Duplicated logic to shared helpers
   - Dead code to removal after confirming it is unused
5. Apply each simplification incrementally and run tests after each change
6. Verify tests pass, the build succeeds, and the resulting diff is clean

If tests fail after a simplification, revert that simplification and reconsider. Finish with a `uncle-dev-code-review-and-quality` style pass over the result.
