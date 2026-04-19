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

Installs AGENTS.md, skills, and agent personas for Codex. Codex reads AGENTS.md automatically from `~/.codex/` (global) or the project root (local).

**Bundle contents:**
- `AGENTS.md` — agent instructions and skill routing rules
- `skills/` — all 20 skill directories with SKILL.md and colocated reference files
- `agents/` — agent personas

**Usage:**
```bash
./scripts/install-codex.sh                              # global user scope (default)
./scripts/install-codex.sh --scope local ~/code/my-app  # project scope
./scripts/install-codex.sh --scope local .              # current directory
./scripts/install-codex.sh --force                      # re-install
```

**Scope destinations:**
- `--scope user` → `~/.codex/`
- `--scope local` → `<workspace>/`

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
| `dist/uncle-dev-codex.tar.gz` | AGENTS.md, skills, agents |
| `dist/uncle-dev-opencode.tar.gz` | AGENTS.md, skills, agents |

Archives are regenerated on every install run. The `dist/` directory is not committed to the repository.

---

## Notes

- All scripts refuse to install into this repository itself.
- Use `--force` to overwrite files during re-installation.
- `AGENTS.md` conflicts prompt for confirmation before replacement (unless `--force`).
- Reference files (checklists, patterns) are colocated inside their respective skill directories, so `skills/` includes them automatically.
