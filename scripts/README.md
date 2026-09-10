# Scripts

This directory contains install scripts for deploying the uncle-dev agent skills pack into AI coding tool environments.

Each script installs the bundle in-place into the target tool's config directory **and** generates a distributable archive in `dist/`.

---

## Tool-specific install scripts

### `cc-others` — Claude Code profile launcher

Runs `claude` with environment variables loaded from `~/.claude_profiles.json`.
Profile values that are strings, numbers, or booleans are exported; `null`
values unset the matching variable.

**Usage:**
```bash
./scripts/cc-others anthropic
./scripts/cc-others glm --dangerously-skip-permissions
./scripts/cc-others claude --resume f4422bb0-473d-40d7-84bc-8b329915876f --qwen
./scripts/cc-others claude --resume f4422bb0-473d-40d7-84bc-8b329915876f --ds
```

**Example `~/.claude_profiles.json`:**
```json
{
  "anthropic": {
    "ANTHROPIC_API_KEY": "sk-ant-...",
    "ANTHROPIC_BASE_URL": null
  },
  "ds": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "<your DeepSeek API Key>",
    "ANTHROPIC_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash",
    "CLAUDE_CODE_SUBAGENT_MODEL": "deepseek-v4-flash",
    "CLAUDE_CODE_EFFORT_LEVEL": "max",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": 786432
  }
}
```

**Requirements:** `jq`, `claude`

### `install-claude.sh` — Claude Code

Installs the full plugin bundle into Claude Code's plugin cache and registers it so commands are available immediately.

**Bundle contents:**
- `commands/` — slash commands (`/uncle-dev-spec`, `/uncle-dev-plan`, `/uncle-dev-build`, `/uncle-dev-test`, `/uncle-dev-review`, `/uncle-dev-code-simplify`, `/uncle-dev-ship`, `/uncle-dev-proactive-memory`)
- `skills/` — all 20 skill directories with SKILL.md and colocated reference files
- `agents/` — agent personas (code-reviewer, test-engineer, security-auditor)
- `hooks/` — session lifecycle hooks
- `.claude-plugin/plugin.json` — plugin metadata

**Usage:**
```bash
./scripts/install-claude.sh                    # user scope (default)
./scripts/install-claude.sh --scope local      # project scope
./scripts/install-claude.sh --force            # re-install
```

**Output:** `dist/uncle-dev-claude.tar.gz`

**Requirements:** `jq`

---

### `install-codex.sh` — OpenAI Codex CLI

See the [Codex installation guide](../docs/improved/guides/tool-setup/codex.md)
for component activation, hook compatibility, and remaining setup gaps.

Installs Uncle Dev as a native Codex plugin assembled at install time from shared repo sources.

**Bundle contents:**
- `plugins/uncle-dev/.codex-plugin/plugin.json` — Codex plugin manifest
- `plugins/uncle-dev/command-templates/` — complete, unchanged command workflows
- `plugins/uncle-dev/skills/` — shared skills with Codex path guidance, plus small `command-*` entries that load full command workflows
- Skill-local `agents/openai.yaml` — presentation metadata, not independent agent definitions
- `plugins/uncle-dev/agents/` — copied from the shared root `agents/` directory at install time
- `.codex/agents/*.toml` — independent native Codex agents, generated from those personas
- `plugins/uncle-dev/CODEX.md` and `COMMANDS.md` — execution guidance and the command invocation catalog
- `.agents/plugins/marketplace.json` — marketplace metadata for Codex plugin discovery

**Usage:**
```bash
./scripts/install-codex.sh                              # user scope (default)
./scripts/install-codex.sh --scope local ~/code/my-app  # project scope
./scripts/install-codex.sh --scope local .              # current directory
./scripts/install-codex.sh --force                      # re-install
```

**Scope destinations:**
- `--scope user` → `~/plugins/uncle-dev` plus `~/.agents/plugins/marketplace.json`
- `--scope local` → `<workspace>/plugins/uncle-dev` plus `<workspace>/.agents/plugins/marketplace.json`

**Output:** `dist/uncle-dev-codex.tar.gz`

The archive contains `plugins/`, `.agents/`, and `.codex/` directly. Activate or
refresh the assembled plugin with the `codex plugin add` command printed by the
installer, then open a new task. Explicit project marketplaces also require
`codex plugin marketplace add`. The generated version carries a reproducible
content hash so changes do not reuse stale plugin caches.

Invoke the full spec workflow with `$command-uncle-dev-spec` (displayed as
`/uncle-dev-spec (command)`). This entry reads the original command and all its
routed skills; it does not substitute `uncle-dev-spec-driven-development` or the
independent `uncle-po` agent. The adapter avoids Codex's 4,000-byte automatic
command migration limit. Claude hooks are not activated, and bundled root rules
do not replace project setup.

---

### `install-opencode.sh` — OpenCode

Installs AGENTS.md, skills, and agent personas for OpenCode.

**Bundle contents:**
- `AGENTS.md` — agent instructions and skill routing rules
- `skills/` — all 20 skill directories with SKILL.md and colocated reference files
- `agents/` — agent personas

**Usage:**
```bash
./scripts/install-opencode.sh --scope global              # global scope
./scripts/install-opencode.sh ~/code/my-app               # local project
./scripts/install-opencode.sh --scope local .             # current directory
./scripts/install-opencode.sh --force                     # re-install
```

**Scope destinations:**
- `--scope global` → `~/.config/opencode/`
- `--scope local` → `<workspace>/.opencode/` (AGENTS.md at workspace root)

**Output:** `dist/uncle-dev-opencode.tar.gz`

---

### `install-goose.sh` — Goose

Installs uncle-dev as a Goose plugin. Goose plugins carry **skills and hooks only** — no slash commands, no subagents.

**Bundle contents:**
- `plugin.json` — Goose manifest, version synced from `.claude-plugin/plugin.json`
- `skills/` — all skill directories with SKILL.md and colocated reference files
- `scripts/` — skill loader and config helper, needed by the command recipes
- 9 agent personas + 31 slash commands as Goose recipes, generated at install time

Hooks are not installed: uncle-dev advisories write JSON to stdout, which Goose reads as its allow/block decision channel. See `goose/README.md`.

**Usage:**
```bash
./scripts/install-goose.sh                                # user scope
./scripts/install-goose.sh --scope project ~/code/my-app  # project scope
./scripts/install-goose.sh --no-recipes                   # skills only
./scripts/install-goose.sh --rules ~/code/my-app          # also copy rules files
./scripts/install-goose.sh --from-git --auto-update       # delegate to goose CLI
./scripts/install-goose.sh --dry-run                      # preview
./scripts/install-goose.sh --force                        # replace existing install
```

**Scope destinations:**

| Scope | Plugin | Recipes |
|---|---|---|
| `user` | `~/.agents/plugins/uncle-dev/` | `~/.config/goose/recipes/` |
| `project` | `<workspace>/.agents/plugins/uncle-dev/` | `<workspace>/.goose/recipes/` |

Recipes install outside the plugin directory because Goose does not discover recipes inside plugins.

`goose plugin install` accepts git URLs only, so the default mode copies into the directory the CLI would have used. Verify with `goose skills list | grep uncle-dev` and `goose recipe list`.

---

### `gen-goose-recipes.sh` — agents + commands → Goose recipes

Goose has no plugin-level format for subagents or slash commands; both are recipes. This converts each `agents/*.md` persona and each `commands/*.md` slash command into a Goose recipe YAML. `agents/` and `commands/` remain the single source of truth.

Recipe YAML is a runtime artefact and is never checked in — `--out` is required and refuses any path inside this repo. `install-goose.sh` calls this script with a temp directory on every run, so installed recipes cannot be stale.

```bash
./scripts/gen-goose-recipes.sh \
  --out ~/.config/goose/recipes \
  --plugin-root ~/.agents/plugins/uncle-dev

./scripts/gen-goose-recipes.sh --out /tmp/r --agents-only     # one kind only
```

**Naming:** commands keep their stem (`uncle-dev-spec.yaml`, mirroring `/uncle-dev-spec`); agents are namespaced `uncle-dev-agent-<name>.yaml`, because `uncle-senior` exists in both `agents/` and `commands/`.

**Command body transforms** (applied to generated YAML only): literal `{{`/`{%` escaped so Goose's Jinja renderer emits them as text; `$ARGUMENTS` → `{{ arguments }}`; `${CLAUDE_PLUGIN_ROOT}` given the installed plugin root as its default, since Goose never sets it. That last one is why `install-goose.sh` stages `scripts/` into the plugin directory.

Agent frontmatter `model:` and `tools:` have no portable Goose equivalent and are emitted as comments rather than dropped.

---

## `install-plugin.sh` — Multi-tool installer

The original multi-tool installer for Copilot, Cursor, Gemini, Windsurf, and OpenCode. Useful for copying skills into non-native tool directories.

**Usage:**
```bash
./scripts/install-plugin.sh [--scope local|global] <target[,target...]> [workspace]
./scripts/install-plugin.sh all .
```

**Targets:** `copilot`, `cursor`, `gemini`, `getting-started`, `windsurf`, `opencode`

For Claude Code, Codex, and OpenCode prefer the dedicated scripts above — they produce complete bundles and distributable archives.

---

## Generated archives (`dist/`)

Each tool's install script generates a `.tar.gz` archive suitable for distribution or offline installation:

| Archive | Contents |
|---------|----------|
| `dist/uncle-dev-claude.tar.gz` | commands, skills, agents, hooks, plugin.json |
| `dist/uncle-dev-codex.tar.gz` | Plugin, full command templates and entries, shared skills, native agents, marketplace.json |
| `dist/uncle-dev-opencode.tar.gz` | AGENTS.md, skills, agents |

Archives are regenerated on every install run. The `dist/` directory is not committed to the repository.

---

## Canonical plugin-root / cache resolution

Every command file and hook that needs to locate a script from the plugin must use this resolution order. **Never hardcode a version string. Never double the marketplace-id segment in the path** (e.g. `…/uncle-dev-agent-skills/uncle-dev/…` is correct; the wrong form doubles the first segment).

```bash
# 1. CLAUDE_PLUGIN_ROOT — set by Claude Code when running as an installed plugin.
# 2. Newest versioned cache entry — sort -V | tail -1 picks the latest version
#    deterministically (never find | head -1, which is nondeterministic).
#
# Real cache layout:
#   ~/.claude/plugins/cache/<marketplace-id>/<plugin-name>/<version>/
#   = ~/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/<version>/

_scripts="${CLAUDE_PLUGIN_ROOT:-}/scripts"
[[ ! -f "$_scripts/uncle-dev-load-skill.sh" ]] && \
  _scripts="$(ls -1d "${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/"*/ 2>/dev/null | sort -V | tail -1)scripts"
```

For prose search lists (no bash block), list the three tiers in order:
1. `${CLAUDE_PLUGIN_ROOT}/scripts/…`
2. `$(ls -1d ~/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/*/ 2>/dev/null | sort -V | tail -1)scripts/…`
3. The agent-skills repo if cloned locally

The `scripts/check-manifest.sh` recurrence guard (R-8.7) enforces these rules on every run — add any new command files to that guard's scope by ensuring they live under `commands/` or `hooks/`.

---

## Notes

- All scripts refuse to install into this repository itself.
- Use `--force` to overwrite files during re-installation.
- `AGENTS.md` conflicts prompt for confirmation before replacement (unless `--force`).
- Reference files (checklists, patterns) are colocated inside their respective skill directories, so `skills/` includes them automatically.
