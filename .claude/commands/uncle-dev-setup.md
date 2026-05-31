Load and execute the `uncle-dev-setup` skill located at `skills/uncle-dev-setup/SKILL.md`.

## Arguments

| Argument | Behaviour                                                                                                                                                                       |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| _(none)_ | First-time setup — scaffolds directories, writes config, injects CLAUDE.md block. Skips preference questions if `.agents/uncle-dev-setup.yaml` already exists.                  |
| `update` | Reconfigure — re-asks preference questions (including level/sdd/tdd/execution_profile/annotations/graphify) and overwrites existing preferences. Tool detection always re-runs. |

## Execution

1. Locate the setup script (plugin cache first, repo clone as fallback):

```bash
SETUP_SCRIPT="${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev-agent-skills/1.4.0/scripts/setup-project.sh"
[ -f "${SETUP_SCRIPT}" ] || SETUP_SCRIPT="$(
  for d in "${UNCLE_DEV_ROOT:-}" ~/others/ai-agents/production-grade-agent-skills ~/agent-skills; do
    [ -f "${d}/scripts/setup-project.sh" ] && echo "${d}/scripts/setup-project.sh" && break
  done
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
jq '.plugins | has("uncle-dev-agent-skills@uncle-dev-agent-skills")' \
  ~/.claude/plugins/installed_plugins.json
```

If `false`: run `bash <AGENT_SKILLS_ROOT>/scripts/install-claude.sh`, then restart Claude Code.
