---
description: Run TDD workflow — write failing tests, implement, verify. For bugs, use the Prove-It pattern.
---

## Working Principles

1. **Think Before Coding** — Understand what the code does before writing tests. Read the spec and identify the right test level: unit, integration, or E2E.
2. **Simplicity First** — Test behavior, not implementation. Avoid testing internals that callers should not depend on.
3. **Surgical Changes** — Write tests for the feature at hand. Don't rewrite the existing suite or improve unrelated coverage.
4. **Goal-Driven Execution** — A test is only done when it fails for the right reason, then passes for the right reason. Green without first seeing red is not TDD.

---

Invoke `uncle-dev-test-driven-development`.

For new features:
1. Write tests that describe the expected behavior and confirm they fail
2. Implement the code to make them pass
3. Refactor while keeping tests green

For bug fixes using the Prove-It pattern:
1. Write a test that reproduces the bug and confirm it fails
2. Implement the fix
3. Confirm the test passes
4. Run the full test suite for regressions

For browser-related issues, also invoke `uncle-dev-browser-testing-with-devtools` to verify behavior with live runtime data.
