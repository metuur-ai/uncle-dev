---
description: Document a recently solved problem into .uncle-dev/learns/ while context is fresh
---

## Working Principles

1. **Think Before Coding** — Confirm the problem is actually solved and verified before starting. Do not document a fix that is still being tested.
2. **Simplicity First** — One file, one problem. Do not create multiple docs or intermediate draft files. Subagents return text; the orchestrator writes the final file.
3. **Surgical Changes** — Write about the specific problem just solved. Do not expand scope to adjacent problems or general best practices unless they are the direct learning.
4. **Goal-Driven Execution** — Success means one structured file at `.uncle-dev/learns/[category]/[filename].md` that another engineer or agent could use to solve the same problem in minutes.

---

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-knowledge-capture
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

Ask the user for Full or Lightweight mode before proceeding. In Full mode, also ask whether to
search session history for relevant prior context.

After the doc is written, run the discoverability check and present the "What's next?" options
using the platform's blocking question tool.
