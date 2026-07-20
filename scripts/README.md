# Scripts

This directory contains install scripts for deploying the uncle-dev agent skills pack into AI coding tool environments.

Each script installs the bundle in-place into the target tool's config directory **and** generates a distributable archive in `dist/`.

---

## Tool-specific install scripts

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

Installs Uncle Dev as a native Codex plugin assembled at install time from shared repo sources.

**Bundle contents:**
- `plugins/uncle-dev/.codex-plugin/plugin.json` — Codex plugin manifest
- `plugins/uncle-dev/commands/` — Codex command entrypoints (`uncle-dev-spec`, `uncle-dev-plan`, etc.)
- `plugins/uncle-dev/skills/` — copied from the shared root `skills/` directory at install time
- `plugins/uncle-dev/agent-manifests/` — Codex-only `openai.yaml` agent manifests copied into the bundled skill trees at install time
- `plugins/uncle-dev/agents/` — copied from the shared root `agents/` directory at install time
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
| `dist/uncle-dev-codex.tar.gz` | Codex plugin wrapper, copied shared skills, copied shared agents, marketplace.json |
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
