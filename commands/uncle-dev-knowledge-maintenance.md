---
description: Review and refresh .uncle-dev/learns/ for accuracy — update stale references, consolidate overlapping docs, replace outdated guidance, delete obsolete learnings
---

## Working Principles

1. **Think Before Coding** — Gather evidence before classifying any doc. Do not ask the user to make decisions before you have investigated the candidate artifacts.
2. **Simplicity First** — Apply the lightest intervention that restores accuracy. Fix a path, not the whole doc. Consolidate when two docs say the same thing, not when they merely share a topic.
3. **Surgical Changes** — Touch only what has drifted. Do not improve wording, add sections, or refactor docs that are still accurate.
4. **Goal-Driven Execution** — Every doc in scope ends with an explicit classification (Keep/Update/Consolidate/Replace/Delete/Stale) and a full report. No doc is silently skipped.

---

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-knowledge-maintenance
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

Pass a scope argument when possible to narrow the review:

```
/uncle-dev-knowledge-maintenance payments          # review docs related to the payments module
/uncle-dev-knowledge-maintenance performance-issues  # review docs in the performance-issues category
/uncle-dev-knowledge-maintenance auth-token-expiry   # review a specific learning by filename
/uncle-dev-knowledge-maintenance mode:autofix        # unattended run — applies all unambiguous actions
```

Without a scope argument, the skill reviews all of `.uncle-dev/learns/`. For large knowledge stores,
a scope argument is strongly recommended to keep the session focused.

After execution, a full report is printed classifying every artifact reviewed. Run the discoverability
check after the report. Offer to commit the changes.
