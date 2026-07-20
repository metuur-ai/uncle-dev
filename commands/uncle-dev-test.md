---
description: Run TDD workflow — write failing tests, implement, verify. For bugs, use the Prove-It pattern.
---

## Working Principles

1. **Think Before Coding** — Understand what the code does before writing tests. Read the spec and identify the right test level (unit, integration, E2E).
2. **Simplicity First** — Test behavior, not implementation. Avoid testing internals that shouldn't be exposed to callers.
3. **Surgical Changes** — Write tests for the feature at hand. Don't rewrite the existing test suite or improve unrelated coverage.
4. **Goal-Driven Execution** — A test is only done when it fails for the right reason, then passes for the right reason. Green without first seeing red is not TDD.

---

## Step 0 — Read SDD mode (do this first)

```bash
_scripts="${CLAUDE_PLUGIN_ROOT:-}/scripts"
[[ ! -f "$_scripts/uncle-dev-detect-mode.sh" ]] && \
  _scripts="$(ls -1d "${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/"*/ 2>/dev/null | sort -V | tail -1)scripts"
_mode=$(bash "$_scripts/uncle-dev-detect-mode.sh")
# For mode semantics see scripts/uncle-dev-detect-mode.sh
```

If you could not run Step 0, treat the mode as `lid-ears`.

**Map test output to the active mode's requirement source:**

- **`lid-ears` mode** — Link each failing or passing test to the requirement IDs in `docs/ears/<slug>.md` (e.g. `R-5.1` that the test covers). Reference the relevant EARS requirement in the test description or comment so coverage is traceable.
- **`openspec` mode** — Link each test to the active change's acceptance criteria or task entries in `openspec/changes/<change-id>/tasks.md` so the test outcome maps to a tracked deliverable.

---

Resolve the active skill (and any project overrides/companions) first, then read runtime preferences:

```bash
_cfg="${_scripts}/uncle-dev-config.sh"
_loader="${_scripts}/uncle-dev-load-skill.sh"
bash "$_loader" uncle-dev-test-driven-development

TDD_MODE=$(bash "$_cfg" preferences.tdd-mode lite 2>/dev/null || echo "lite")
EXECUTION_PROFILE=$(bash "$_cfg" preferences.execution_profile balanced 2>/dev/null || echo "balanced")
echo "$TDD_MODE"
echo "$EXECUTION_PROFILE"
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

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

For browser-related issues, also resolve the browser-testing skill and honor its `SKILL:`/`COMPANION:` lines:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-browser-testing-with-devtools
```

Then verify in the browser via Chrome DevTools MCP.
