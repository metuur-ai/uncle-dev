---
description: Harvest all @debt markers into a ledger showing each shortcut's location, ceiling, and upgrade path — flagging any missing a ceiling or upgrade as silent-rot risk
---

Run the `@debt` harvester and present its ledger.

`@debt <ceiling>, <upgrade>` marks a consciously-kept shortcut with its limit and its escape hatch. It is distinct from `@spec` (forward traceability) and `[D]` (unbuilt-requirement status). See `skills/uncle-dev-spec-annotations/SKILL.md` for the grammar.

The harvester script is `harvest-debt.py` in the `uncle-dev-spec-annotations` skill.

1. Locate the script. Search in this order:
   - `${CLAUDE_PLUGIN_ROOT}/skills/uncle-dev-spec-annotations/harvest-debt.py`
   - `~/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev-agent-skills/skills/uncle-dev-spec-annotations/harvest-debt.py`
   - The agent-skills repo if cloned locally

2. Run the harvester from the project root:

```bash
python3 <path-to-harvest-debt.py> --root "$(pwd)"
```

   JSON output (for further processing):

```bash
python3 <path-to-harvest-debt.py> --root "$(pwd)" --format json
```

3. Show the user the ledger. The report format is:

   ```
   @debt ledger (root: ...)

     N marker(s): N well-formed, N silent-rot risk

     ✗ SILENT-ROT RISK: <file>:<line> — <reason>
         ceiling: ...  upgrade: ...
     ✓ <file>:<line>
         ceiling: ...
         upgrade: ...

   Summary: ...
   ```

   Silent-rot-risk markers (missing a ceiling or upgrade) are sorted to the TOP — a shortcut with no recorded limit or exit is debt that rots silently.

4. **If silent-rot-risk markers exist** (the harvester exits non-zero):
   - For each, surface the location and what's missing
   - Recommend the author either complete the marker (`@debt <ceiling>, <upgrade>` with both fields) or remove the shortcut
   - A `@debt` marker is not a TODO dump: if the shortcut has no real ceiling or upgrade, it does not belong as `@debt`

5. **If all markers are well-formed:** present the ledger as the standing debt inventory — each entry is a deliberate shortcut whose ceiling tells you when it must be upgraded.

If the script is not found, tell the user: "harvest-debt.py not found. Run `install-claude.sh` from the agent-skills repo, or clone the repo locally."
