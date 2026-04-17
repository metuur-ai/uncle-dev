---
description: Conduct a five-axis code review — correctness, readability, architecture, security, performance
---

## Working Principles

1. **Think Before Coding** — Read the spec or task description before reading the code. Understand intent before evaluating implementation.
2. **Simplicity First** — Flag over-engineering as a real finding. 200 lines that could be 50 is a code quality issue, not a style preference.
3. **Surgical Changes** — Review the diff, not the whole file. Pre-existing issues that aren't in scope get a note, not a blocking finding.
4. **Goal-Driven Execution** — APPROVE only when all Critical issues are resolved and tests verify the behavior. Every finding includes a specific fix.

---

Invoke the agent-skills:code-review-and-quality skill.

Review the current changes (staged or recent commits) across all five axes:

1. **Correctness** — Does it match the spec? Edge cases handled? Tests adequate?
2. **Readability** — Clear names? Straightforward logic? Well-organized?
3. **Architecture** — Follows existing patterns? Clean boundaries? Right abstraction level?
4. **Security** — Input validated? Secrets safe? Auth checked? (Use security-and-hardening skill)
5. **Performance** — No N+1 queries? No unbounded ops? (Use performance-optimization skill)

Categorize findings as Critical, Important, or Suggestion.
Output a structured review with specific file:line references and fix recommendations.
