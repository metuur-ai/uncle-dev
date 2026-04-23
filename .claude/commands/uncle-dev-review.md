---
description: Conduct a five-axis code review — correctness, readability, architecture, security, performance
---

## Working Principles

1. **Think Before Coding** — Read the spec or task description before reading the code. Understand intent before evaluating implementation.
2. **Simplicity First** — Flag over-engineering as a real finding. 200 lines that could be 50 is a code quality issue, not a style preference.
3. **Surgical Changes** — Review the diff, not the whole file. Pre-existing issues that aren't in scope get a note, not a blocking finding.
4. **Goal-Driven Execution** — APPROVE only when all Critical issues are resolved and tests verify the behavior. Every finding includes a specific fix.

---

Invoke the agent-skills:uncle-dev-code-review-and-quality skill.

Check if the OpenSpec CLI is available (`openspec --version`). When available, use it to load change context before reviewing:

- `openspec show <change-id>` to read the change's proposal and design for intent verification
- `openspec validate <change-id>` to check artifact consistency alongside the code review

If not installed, recommend `npm install -g openspec` and read change artifacts directly.

Detect the review mode from the user's input and dispatch accordingly:

**`/uncle-dev-review`** (full) — Run three parallel agents (code quality, architecture, change impact), then synthesize with `uncle-dev-ag-review-synthesizer`. Use for significant changes (>300 lines, security-sensitive, or architectural decisions).

**`/uncle-dev-review --quick`** — Run `uncle-dev-ag-code-reviewer` only. Use for small, focused changes.

**`/uncle-dev-review --security`** — Full parallel mode plus `uncle-dev-ag-security-auditor` added to the parallel phase.

**`/uncle-dev-review PR #NNN`** — Fetch the PR diff first with `gh pr diff NNN`, then run full mode on the diff.

For full and security modes, use the Parallel Orchestration Mode from the skill:
1. Spawn all agents in background concurrently
2. Wait for all to complete
3. Pass all outputs to `uncle-dev-ag-review-synthesizer`
4. Present the synthesized verdict (APPROVE / REQUEST_CHANGES / NEEDS_DISCUSSION), blocking issues, non-blocking issues, and PR summary

For quick mode, review across all five axes directly:

1. **Correctness** — Does it match the spec? Edge cases handled? Tests adequate?
2. **Readability** — Clear names? Straightforward logic? Well-organized?
3. **Architecture** — Follows existing patterns? Clean boundaries? Right abstraction level?
4. **Security** — Input validated? Secrets safe? Auth checked? (Use security-and-hardening skill)
5. **Performance** — No N+1 queries? No unbounded ops? (Use performance-optimization skill)

Categorize findings as Critical, Important, or Suggestion.
Output a structured review with specific file:line references and fix recommendations.
