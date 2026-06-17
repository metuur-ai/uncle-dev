---
description: Generate a user-facing changelog from git history — draft, review, then write CHANGELOG.md
---

## Working Principles

1. **Think Before Coding** — Determine the commit range and target version before drafting. If the version source is ambiguous, ask.
2. **Simplicity First** — 3–8 lines per version is healthy. Drop noise instead of summarizing it.
3. **Surgical Changes** — Touch only `CHANGELOG.md`. No version bumps, no tags, no commits unless the user asks.
4. **Goal-Driven Execution** — Success means a reviewed changelog entry where every line states a user-visible outcome.

---

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-changelog
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

Follow the skill's Core Process: determine the range, build the scope→surface map, filter noise, draft, then **pause for the user's review before writing CHANGELOG.md**.

If the user passed an argument (e.g. a version number or "since v0.7.20"), use it as the range/target instead of auto-detecting.
