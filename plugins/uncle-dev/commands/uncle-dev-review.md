---
description: Conduct a five-axis code review — correctness, readability, architecture, security, performance
---

## Working Principles

1. **Think Before Coding** — Read the spec or task description before reading the code. Understand intent before evaluating implementation.
2. **Simplicity First** — Flag over-engineering as a real finding. 200 lines that could be 50 is a code quality issue, not a style preference.
3. **Surgical Changes** — Review the diff, not the whole file. Pre-existing issues that aren't in scope get a note, not a blocking finding.
4. **Goal-Driven Execution** — APPROVE only when all Critical issues are resolved and tests verify the behavior. Every finding includes a specific fix.

---

## Step 0 — Read SDD mode and load intent context

```bash
_scripts="${CLAUDE_PLUGIN_ROOT:-}/scripts"
[[ ! -f "$_scripts/uncle-dev-detect-mode.sh" ]] && \
  _scripts="$(ls -1d "${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/"*/ 2>/dev/null | sort -V | tail -1)scripts"
_mode=$(bash "$_scripts/uncle-dev-detect-mode.sh")
# For mode semantics see scripts/uncle-dev-detect-mode.sh
```

If you could not run Step 0, treat the mode as `lid-ears`.

**Load intent context based on sdd_mode before reviewing any code:**

- **`lid-ears` mode** — Read `docs/hld/<slug>.md` (goals, non-goals), `docs/lld/<slug>.md` (constraints, key decisions), and `docs/ears/<slug>.md` (EARS requirements the code must satisfy). Use these as the intent source for verifying correctness. Do NOT run any `openspec` command.
- **`openspec` mode** — Check if the OpenSpec CLI is available (`openspec --version`). When available: `openspec show <change-id>` to read proposal and design, `openspec validate <change-id>` to check artifact consistency. If not installed, recommend `npm install -g openspec` and read change artifacts directly.

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-code-review-and-quality
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

Read execution profile to choose default review depth:

```bash
EXECUTION_PROFILE=$(bash "$_cfg" preferences.execution_profile balanced 2>/dev/null || echo "balanced")
echo "$EXECUTION_PROFILE"
```

Detect the review mode from the user's input and dispatch accordingly:

**`/uncle-dev-review`** default mode by profile:
- `fast` -> quick mode by default
- `balanced` -> quick for small/focused diffs, full for large/risky diffs
- `strict` -> full mode by default

Full mode = run three parallel agents (code quality, architecture, change impact), then synthesize with `uncle-dev-ag-review-synthesizer`. Use for significant changes (>300 lines, security-sensitive, or architectural decisions).

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
