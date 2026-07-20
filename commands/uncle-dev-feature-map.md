---
description: Discover and catalog product features by reading backend routes, controllers, service logic, and frontend pages/components. Run before brownfield analysis or when building a product-level inventory of an unfamiliar codebase.
---

## Working Principles

1. **Think Before Coding** — Identify the stack and entry-point directories before spawning any agents.
2. **Simplicity First** — Focus on what users can do, not how it is implemented.
3. **Surgical Changes** — Write the feature map document only; do not suggest architectural changes.
4. **Goal-Driven Execution** — Done when every user-facing capability is named in product language with backend + frontend coverage noted.

---

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(ls -1d "${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/"*/ 2>/dev/null | sort -V | tail -1)scripts/uncle-dev-load-skill.sh
bash "$_loader" uncle-dev-feature-map
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

Follow the skill's Core Process: detect stack and entry points, spawn parallel backend and frontend scouts, merge into a feature catalog, and write the map to `.uncle-dev/feature-maps/YYYY-MM-DD-<slug>.md`.

If the user passed a path or a scope description, use it to narrow which part of the codebase to map. Otherwise map the entire repository.
