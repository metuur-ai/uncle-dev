---
description: Research the codebase as-is — parallel subagent exploration synthesized into a documented map in .devlocal/research/
---

## Working Principles

1. **Think Before Coding** — Read any directly mentioned files fully before spawning subagents. Intent first, then decompose.
2. **Simplicity First** — Spawn the minimum agents needed to answer the question. Don't research everything when the question is specific.
3. **Surgical Changes** — Document the scope the user asked about. Note related areas you discover, but don't expand scope without asking.
4. **Goal-Driven Execution** — Research is complete when the user's question is concretely answered with file:line evidence and a research document exists in `.devlocal/research/`.

---

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-research
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

Ask the user for their research question if they haven't provided one. Then:

1. Read any directly mentioned files fully before spawning subagents
2. Decompose the question into investigation areas
3. Spawn parallel scout subagents (one per area) — documentarians, not evaluators
4. Search `.uncle-dev/learns/` for historical context on the topic
5. Synthesize findings and write a research document to `.devlocal/research/YYYY-MM-DD-[ticket]-description.md`
6. Present a concise summary with key file references

**You are documenting what IS, not what should be.** No recommendations, no critiques, no suggestions unless the user explicitly asks.
