# Scripts

This directory contains helper scripts for installing the agent-skills pack into other workspaces.

## `install-plugin.sh`

`install-plugin.sh` copies the repository's skills, agents, references, and tool-specific config files into either:

- a local project root
- a supported global home-directory location for the target tool

It is intended for local setup from this repository clone.

Use `--scope local` for project installs and `--scope global` for home-directory installs.

### Usage

```bash
./scripts/install-plugin.sh [--scope local|global] <target[,target...]> [workspace]
./scripts/install-plugin.sh [--scope local|global] all [workspace]
```

With `--scope local`, `workspace` is the destination project root. If omitted, the script asks for confirmation before using the current directory.

With `--scope global`, do not pass a workspace. The script installs into a target-specific directory under your home directory.

If the target workspace does not exist yet, the script creates it.

The script refuses to install into this repository itself. You must pass a separate destination project root.

### Options

```bash
--scope     Install into a project (`local`) or a home-level tool directory (`global`)
--force     Overwrite files that already exist
-h, --help  Show the built-in help text
```

By default, the script:

- merges existing directories
- skips identical files
- refuses to overwrite different existing files

Special case:

- if `AGENTS.md` differs, the script asks for confirmation before replacing it

Use `--force` to replace files during re-installation.

### Supported Targets

| Target | `local` install | `global` install |
|--------|-----------------|------------------|
| `copilot` | `.github/skills/` and `.github/agents/` | Not supported by this script |
| `cursor` | `.cursor/rules/` | Not supported by this script |
| `gemini` | `.gemini/skills/` | `~/.gemini/skills/` |
| `getting-started` | `.agents/skills/`, `.agents/agents/`, `.agents/references/` | `~/.agents/skills/`, `~/.agents/agents/`, `~/.agents/references/` |
| `windsurf` | `.windsurf/rules/*.md` | Not supported by this script |
| `opencode` | `AGENTS.md` and `.opencode/skills/` | `~/.config/opencode/AGENTS.md` and `~/.config/opencode/skills/` |
| `all` | Runs every supported local target against one workspace | Fails for targets without global support |

### Examples

Install the recommended Cursor rules into a project:

```bash
./scripts/install-plugin.sh cursor ~/code/my-app
```

Install Gemini globally:

```bash
./scripts/install-plugin.sh --scope global gemini
```

Install OpenCode globally:

```bash
./scripts/install-plugin.sh --scope global opencode
```

Install both Copilot and OpenCode assets into the same local workspace:

```bash
./scripts/install-plugin.sh copilot,opencode ~/code/my-app
```

Install every supported target into the current directory:

```bash
./scripts/install-plugin.sh all .
```

If you omit the workspace for a local install, the script will prompt before installing into the current directory.

Replace existing files when re-installing:

```bash
./scripts/install-plugin.sh gemini ~/code/my-app --force
```

### What the Script Does

The script is copy-based. It does not download dependencies or call external package managers.

It reads from this repository and writes tool-specific files into the destination workspace:

- Copilot: copies selected skills and agent personas into `.github/`
- Cursor: copies the recommended rules into `.cursor/rules/`
- Gemini: copies the full `skills/` directory into `.gemini/skills/` or `~/.gemini/skills/`
- Getting Started: copies the full portable pack into `.agents/` or `~/.agents/`
- Windsurf: copies the recommended rules into `.windsurf/rules/`
- OpenCode: copies `AGENTS.md` and the full `skills/` directory into `.opencode/skills/` or `~/.config/opencode/skills/`

### Notes

- Run the script from the root of this repository so relative paths resolve correctly.
- `--force` may be placed before or after positional arguments.
- Use `all` only when you intentionally want one workspace to contain every supported integration.
- Some tools expose global rules through UI settings rather than a documented file path. For those targets, this script only supports `--scope local`.
- `.devlocal/` is unrelated to this installer. It is part of the OpenSpec workflow, not part of the installation layout.
