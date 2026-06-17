# scripts/lib

Shared library sourced by the installer and guard scripts. The canonical asset inventory lives here.

## Entry Points
- `manifest.sh` — canonical `ASSET_*` roots (`ASSET_SKILLS_ROOT="skills"`, `ASSET_AGENTS="agents"`, `ASSET_COMMANDS_ROOT="commands"`, hooks, scripts, plugin meta, rules). Single source of truth for the skill/agent/command inventories.
- `manifest-allowlist.sh` — intentional-exclusion allowlist for the drift guard (`ALLOWLIST_SKILLS`, `ALLOWLIST_COMMANDS`). Empty by default; an entry means "intentionally excluded from a copy, with a written reason".
- `split-skill-branch.sh` — install-time mode-branch splitter (sourced, not executed). Exposes `split_skill_branch <src> <dest> <sdd_mode>`; trims a dual-branch SKILL.md to the single active branch. Fails loud on partial/unmatched markers; copies verbatim when no markers exist. Opt-in via `UNCLE_DEV_SPLIT_SKILLS=1` in `../install-plugin.sh` (default OFF = byte-identical). Resolves mode only through `../uncle-dev-config.sh`.

## Contracts & Invariants
- `manifest.sh` is the ONLY place an asset root is declared. Adding an installable asset = one edit here; never hard-code roots in installers or guards.
- Copies of the inventory (`.claude-plugin/marketplace.json`, `plugins/uncle-dev/commands/`, README counts) are ENFORCED against these roots by `../check-manifest.sh`, never re-authored as a second source of truth.
- The allowlist is the only sanctioned way to keep a canonical asset out of a copy, and every entry must carry a reason comment.

## Anti-patterns
- Never add a second inventory list (e.g. a hardcoded skill array) in any installer or guard — read `manifest.sh`.
- Never silence a drift by deleting the canonical asset; either reconcile the copy or add a justified allowlist entry.

## Related Context
- Guard: `../check-manifest.sh` (sources both files; invoked by `install.sh verify` and `tests/run-all.sh`).
- AGENTS.md authoring: `../../skills/uncle-dev-context-engineering/agents-md-guide.md`
