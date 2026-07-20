---
description: Pre-mortem analysis that imagines a plan has failed, then works backward to identify causes and preventions. Use before launches, major decisions, or risky initiatives to surface hidden risks.
---

## Working Principles

1. **Think Before Coding** — Understand the plan or initiative fully before generating failure scenarios.
2. **Simplicity First** — Surface the most likely failure modes first; depth over breadth.
3. **Surgical Changes** — Document risk findings only; do not redesign the plan.
4. **Goal-Driven Execution** — Done when every identified failure mode has a concrete prevention action.

---

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(ls -1d "${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/"*/ 2>/dev/null | sort -V | tail -1)scripts/uncle-dev-load-skill.sh
bash "$_loader" uncle-dev-pre-mortem
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

Follow the skill's Core Process: set the scene, generate failure scenarios without filtering, then prioritize and map each failure to a concrete prevention action.

If the user passed an argument (e.g. a plan file path, a change-ID, or a description of the initiative), use it as the scope. Otherwise ask for it.
