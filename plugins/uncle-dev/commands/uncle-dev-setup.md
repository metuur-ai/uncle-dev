---
description: "Wire uncle-dev into this project — plugin check, scaffolding, config, hooks"
---

Load and execute the `uncle-dev-setup-local` skill located at `skills/uncle-dev-setup-local/SKILL.md`.

## Arguments

| Argument | Behaviour                                                                                                                                                                       |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| _(none)_ | First-time setup — scaffolds directories, writes config, injects CLAUDE.md block. Skips preference questions if `.agents/uncle-dev-setup.yaml` already exists.                  |
| `update` | Reconfigure — re-asks preference questions (including level/sdd/tdd/execution_profile/annotations/graphify) and overwrites existing preferences. Tool detection always re-runs. |

## Execution

1. Locate the setup script. Resolution order: `CLAUDE_PLUGIN_ROOT` (set by Claude Code) → repo-local checkout → newest versioned plugin cache:

```bash
SETUP_SCRIPT="${CLAUDE_PLUGIN_ROOT:-}/scripts/setup-project.sh"
[ -f "${SETUP_SCRIPT}" ] || SETUP_SCRIPT="$(
  _cache_dir=$(ls -1d "${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/"*/ 2>/dev/null | sort -V | tail -1)
  echo "${_cache_dir}scripts/setup-project.sh"
)"
```

2. Run the script from the **current project root**:
   - No argument or unrecognized argument → `bash "${SETUP_SCRIPT}"`
   - `update` → `bash "${SETUP_SCRIPT}" --update`

3. **Do not proceed without running the script.** The script interactively asks the user preference questions. The agent must not answer on the user's behalf or apply defaults silently.

4. After the script completes, validate config and then check plugin installation:

```bash
bash scripts/uncle-dev-config.sh --validate
```

If invalid, fix `.agents/uncle-dev-setup.yaml` using `scripts/uncle-dev-setup.schema.json`, then re-run validation.

By default, setup config includes wrap thresholds used by hooks:

- `preferences.wrap_trigger.context_window_percent: 70`
- `preferences.wrap_trigger.total_tokens: 130000`

5. Check plugin installation:

```bash
jq '.plugins | keys[]' ~/.claude/plugins/installed_plugins.json 2>/dev/null | grep -q '^"uncle-dev@'
```

If the key is not present: run `bash <AGENT_SKILLS_ROOT>/scripts/install-claude.sh`, then restart Claude Code.
