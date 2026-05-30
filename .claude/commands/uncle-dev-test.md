---
description: Run TDD workflow — write failing tests, implement, verify. For bugs, use the Prove-It pattern.
---

## Working Principles

1. **Think Before Coding** — Understand what the code does before writing tests. Read the spec and identify the right test level (unit, integration, E2E).
2. **Simplicity First** — Test behavior, not implementation. Avoid testing internals that shouldn't be exposed to callers.
3. **Surgical Changes** — Write tests for the feature at hand. Don't rewrite the existing test suite or improve unrelated coverage.
4. **Goal-Driven Execution** — A test is only done when it fails for the right reason, then passes for the right reason. Green without first seeing red is not TDD.

---

Invoke the agent-skills:uncle-dev-test-driven-development skill.

Read runtime preferences first:

```bash
_cfg="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-config.sh"
[[ ! -f "$_cfg" ]] && _cfg=$(find "${HOME}/.claude/plugins" -name "uncle-dev-config.sh" 2>/dev/null | head -1)
TDD_MODE=$(bash "$_cfg" preferences.tdd-mode lite 2>/dev/null || echo "lite")
EXECUTION_PROFILE=$(bash "$_cfg" preferences.execution_profile balanced 2>/dev/null || echo "balanced")
echo "$TDD_MODE"
echo "$EXECUTION_PROFILE"
```

For new features:
1. Write tests that describe the expected behavior (they should FAIL)
2. Implement the code to make them pass
3. Refactor while keeping tests green

For bug fixes (Prove-It pattern):
1. Write a test that reproduces the bug (must FAIL)
2. Confirm the test fails
3. Implement the fix
4. Confirm the test passes
5. Regression verification:
   - `strict` -> full test suite
   - `balanced` -> targeted suite now; full suite before merge
   - `fast` -> targeted suite only unless user asks full

When `tdd-mode: lite`, red-first and prove-it are recommended but not mandatory for minor/trivial fixes.

For browser-related issues, also invoke agent-skills:uncle-dev-browser-testing-with-devtools to verify with Chrome DevTools MCP.
