---
description: Map a big initiative into its impacted items and a visual breakdown — tiered YAML tracker + map + per-item stubs in .uncle-dev/initiative-maps/
---

## Working Principles

1. **Think Before Coding** — Read the objective (and any file it points to) fully before spawning subagents. Understand the initiative before decomposing it.
2. **Simplicity First** — Identify the BIG items only (main workstreams). One level of breakdown; sub-items live in stubs. Don't slip into spec/task grain.
3. **Surgical Changes** — Map the initiative the user named. Note adjacent impact you discover, but don't expand scope without asking.
4. **Goal-Driven Execution** — Done when a tiered tracker, a rendered map (table + diagram + per-item why/what/what-if/how), an ADR register, and one stub per item exist in `.uncle-dev/initiative-maps/`.

---

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-initiative-map
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

If the user gave no objective, ask for it: a high-level requirement, design, major feature, greenfield/brownfield project, or any large initiative — plus which repos/platforms it spans (if multi-repo). Then follow `uncle-dev-initiative-map`:

1. Frame the initiative and detect scope (greenfield vs brownfield, one repo vs many)
2. Gather platform context (reuse `uncle-dev-feature-map` per repo; read arch docs; use graphify/spec-graph if present)
3. Identify the BIG items — each with `id`, `tier`, and the four lenses: **why / what / what if / how** (one line each)
4. Map dependencies & interactions, then derive tiers, critical paths, and milestones
5. Flag which decisions need an ADR (one ADR per decision, phrased as a question — defer authoring to `uncle-dev-documentation-and-adrs`)
6. Assign a stakeholder and SME per item (source from CODEOWNERS / AGENTS.md / git, or mark `TBD` — never invent)
7. Write the canonical `<slug>-tracker.yaml`, the rendered `YYYY-MM-DD-<slug>.md` map, and one stub per item
8. Present the quick-view table, the breakdown diagram, and the ADRs-needed register

**This is a visualization and decomposition aid — not the spec chain.** Do NOT write specs, tasks, or code, and do NOT run HLD/LLD/EARS or pre-mortem here. Each big item hands off downstream to `uncle-dev-grill`/`uncle-dev-spec`; each flagged decision to `uncle-dev-documentation-and-adrs`.

ARGUMENTS: $ARGUMENTS
