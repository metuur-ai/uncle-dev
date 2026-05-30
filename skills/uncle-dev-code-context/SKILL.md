> ## Documentation Index
> Fetch the complete documentation index at: https://agentskills.io/llms.txt
> Use this file to discover all available pages before exploring further.

---
name: uncle-dev-code-context
description: "CONVERTED TO RULE. This skill's enforcement logic now lives as the 'Code Context' rule in the uncle-dev section of CLAUDE.md. Install that rule in any project that uses uncle-dev. See uncle-dev-context-engineering for the full context hierarchy strategy and agents-md-guide.md for the AGENTS.md authoring template."
---

# code-context → now a CLAUDE.md rule

This skill has been converted to an always-on rule.

## Why

A pre-edit gate that requires explicit invocation can be skipped. Rules in CLAUDE.md are enforced automatically on every session — no invocation required.

## The Rule

Add this to the `## uncle-dev` section of your project's CLAUDE.md:

```markdown
### Code Context (always enforced)
- Before editing any file, check if its directory has an `AGENTS.md` — if so, read it first
- If no `AGENTS.md` exists in a source directory, create one before editing
- After adding, moving, or deleting source directories, update the affected `AGENTS.md` files in the same turn
- Respect architecture boundaries defined in `AGENTS.md` — never import across them without explicit justification
- CLAUDE.md and AGENTS.md must not coexist at project root — choose one
```

## Related

- `uncle-dev-context-engineering` — strategy skill for the full context hierarchy
- `uncle-dev-context-engineering/agents-md-guide.md` — template, quality checklist, SME capture questions
