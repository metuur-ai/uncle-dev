---
description: Conduct a five-axis code review — correctness, readability, architecture, security, performance
---

## Working Principles

1. **Think Before Coding** — Read the spec or task description before reading the code. Understand intent before evaluating implementation.
2. **Simplicity First** — Flag over-engineering as a real finding. Two hundred lines that could be fifty is a code quality issue, not a style preference.
3. **Surgical Changes** — Review the diff, not the whole file. Pre-existing issues that aren't in scope get a note, not a blocking finding.
4. **Goal-Driven Execution** — Approve only when blocking issues are resolved and tests verify the behavior. Every finding includes a specific fix.

---

Invoke `uncle-dev-code-review-and-quality`.

Detect the review mode from the user's input and dispatch accordingly:

**`uncle-dev-review`** — Run the full five-axis review. Use for significant changes, security-sensitive work, or architecture changes.

**`uncle-dev-review --quick`** — Review the change directly for a focused pass on a small diff.

**`uncle-dev-review --security`** — Full review plus `uncle-dev-security-and-hardening`.

**`uncle-dev-review PR #NNN`** — Fetch the PR diff first with `gh pr diff NNN`, then review the diff instead of the working tree.

For every review, cover:

1. **Correctness** — Does it match the spec? Are edge cases handled? Are tests adequate?
2. **Readability** — Are names clear? Is the logic straightforward? Is the organization sane?
3. **Architecture** — Does it follow existing patterns and keep clean boundaries?
4. **Security** — Is input validated? Are secrets handled safely? Is auth checked where required?
5. **Performance** — Are there obvious N+1 patterns, unbounded operations, or unnecessary heavy work?

Categorize findings as Critical, Important, or Suggestion. Output a structured review with specific file and line references plus recommended fixes.
