# scripts

Install, setup, config, and lint tooling for the uncle-dev plugin. Bash + small inline Python (PyYAML/jsonschema).

## Entry Points
- `install-*.sh` — per-host installers (claude, codex, opencode, hermes, antigravity); `install-plugin.sh`/`install.sh` orchestrate.
- `setup-project.sh` — wires uncle-dev into a target project.
- `uncle-dev-config.sh` — reads config values from `.agents/uncle-dev-setup.yaml` (scalar, `--list`, `--validate`).
- `uncle-dev-load-skill.sh` — resolves and prints a skill body for a host.
- `lint-skills.sh` — nori-lint over SKILL.md files.
- `lib/manifest.sh` — canonical skill/agent/command/rule inventories (single source of truth).

## Contracts & Invariants
- `uncle-dev-config.sh` is the SOLE reader of the setup YAML at `.agents/`. No other script, hook, or command may open/cat/yq that file. Audit guard: `grep -rn 'open.*setup\.yaml\|cat.*setup\.yaml\|yq.*setup\.yaml' scripts/ .claude/ hooks/` returns only the helper.
- Config resolution order (scalar lookups): `UNCLE_DEV_<KEY>` env var → YAML value → caller default. `<KEY>` = dotted path uppercased with dots→underscores (e.g. `preferences.sdd_mode` → `UNCLE_DEV_PREFERENCES_SDD_MODE`). Env tier does not apply to `--list`.
- `lib/manifest.sh` stays the single source of truth for inventories; copies (marketplace.json, README counts) are enforced, not re-authored.

## Patterns
To add a config value lookup from another script:
1. Call `bash scripts/uncle-dev-config.sh <dotted.path> [default]`. Never read the YAML directly.

## Anti-patterns
- Never read the setup YAML directly outside `uncle-dev-config.sh`.
- Never introduce a second source of truth for the asset inventories — extend `lib/manifest.sh`.

## Related Context
- Tests: `./tests/AGENTS.md`
- AGENTS.md authoring: `../skills/uncle-dev-context-engineering/agents-md-guide.md`
