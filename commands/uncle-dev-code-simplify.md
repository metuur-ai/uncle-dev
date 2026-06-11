---
description: Simplify code for clarity and maintainability — reduce complexity without changing behavior
---

## Working Principles

1. **Think Before Coding** — Understand the code's purpose, callers, and edge cases before touching it. Never simplify what you don't fully understand.
2. **Simplicity First** — Simplify toward clarity, not cleverness. A longer readable function beats a terse cryptic one.
3. **Surgical Changes** — Only simplify code in the specified scope. Don't fix adjacent issues you notice along the way.
4. **Goal-Driven Execution** — Success means all tests still pass, the diff is smaller, and the code reads more easily than before.

---

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-code-simplification
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

Simplify recently changed code (or the specified scope) while preserving exact behavior:

1. Read CLAUDE.md and study project conventions
2. Identify the target code — recent changes unless a broader scope is specified
3. Understand the code's purpose, callers, edge cases, and test coverage before touching it
4. Scan for simplification opportunities:
   - Deep nesting → guard clauses or extracted helpers
   - Long functions → split by responsibility
   - Nested ternaries → if/else or switch
   - Generic names → descriptive names
   - Duplicated logic → shared functions
   - Dead code → remove after confirming
5. Apply each simplification incrementally — run tests after each change
6. Verify all tests pass, the build succeeds, and the diff is clean

If tests fail after a simplification, revert that change and reconsider. Use `code-review-and-quality` to review the result.
