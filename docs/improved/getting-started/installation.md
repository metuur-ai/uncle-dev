---
sidebar_position: 2
---

# 2. How to Install Uncle Dev

Uncle Dev is modular and installs into several AI coding tools. This guide shows you how to set up the skills in each supported tool.

## Prerequisites

Before you begin, ensure you have:

- `git` installed
- The target AI coding tool installed (Claude Code, Codex, Cursor, OpenCode, GitHub Copilot, or Gemini CLI)
- A local clone of the repository for any script-based install:

```bash
git clone https://github.com/addyosmani/agent-skills.git
```

## Install for Claude Code (Recommended)

Claude Code is a CLI agent that supports plugins.

**Via Marketplace:**
```bash
/plugin install uncle-dev@uncle-dev-agent-skills
```

**Local/Development Install (from cloned repo):**
```bash
git clone https://github.com/addyosmani/agent-skills.git
claude --plugin-dir /path/to/agent-skills
```

## Install for Codex

See [Codex installation and hook compatibility](../guides/tool-setup/codex.md)
for the full component contract, activation checks, and the hook review.

Codex installs Uncle Dev as a native local plugin assembled from the shared source directories in this repository.

**User Installation:**
```bash
./scripts/install-codex.sh
codex plugin add uncle-dev@uncle-dev
```

**Local Project Installation:**
```bash
./scripts/install-codex.sh --scope local /path/to/your/project
codex plugin marketplace add /path/to/your/project
codex plugin add uncle-dev@uncle-dev
```

Run the installer from this repository. Local scope targets another project,
not the installer source repository. Use the marketplace name printed by the
installer if your existing marketplace has a different name. A personal
marketplace is discovered automatically; an explicit project marketplace must
be registered. Open a new Codex task after activating or reinstalling the plugin.

The installer assembles these distinct components:

| Component | Installed location | Use in Codex |
|---|---|---|
| Shared skills | `plugins/uncle-dev/skills/<skill>/` | Invoke the skill by its own name |
| Complete command templates | `plugins/uncle-dev/command-templates/` | Loaded by the corresponding command entry |
| Command entries | `plugins/uncle-dev/skills/command-<command>/` | Select `/uncle-dev-spec (command)` or type `$command-uncle-dev-spec` |
| Agent source profiles | `plugins/uncle-dev/agents/` | Original independent personas |
| Native agents | `.codex/agents/*.toml` in the selected scope | Ask Codex to delegate to `uncle-po`, `uncle-lead`, `uncle-dev-ag-code-reviewer`, etc. |
| Scripts and rule references | Plugin root | Commands use the bundled helpers; project setup activates project instructions |

A command entry reads the **entire original command**, including all routed
skills and companion instructions. It does not replace the command with one
skill. For example:

```text
$command-uncle-dev-spec Specify invitations for new team members.
```

Codex's automatic command migration skips rendered commands larger than 4,000
bytes and some source-host template syntax. The installer avoids that lossy
migration by generating small explicit entry points with references to complete,
unchanged templates. These are Codex skill entry points, not new built-in slash
commands. `COMMANDS.md` inside the assembled plugin lists every mapping.

`agents/openai.yaml` inside a skill is presentation metadata, not an independent
agent registration. Skills display their skill names; native personas use the
agent source filenames. Source-host model aliases such as `sonnet` and `opus`
are not copied into Codex model settings; agents inherit the session settings.

For updates, rerun the installer with `--force`, then run the printed
`codex plugin add` command. The assembled version includes a reproducible content
hash to invalidate stale Codex caches without changing the repository's release
version. Existing conflicting files require `--force`; unrelated agents remain.
The generated archive includes the plugin, marketplace, and native agent files.

Claude-specific lifecycle hooks are **not activated** by this installer; this
does not mean Codex lacks hook support. Rule files bundled inside a plugin are
not automatically project instructions. Run `$command-uncle-dev-setup` in the
target project to configure its Uncle Dev workflow.

## Install for Cursor

Cursor reads instruction rules from the `.cursor/rules/` directory.

**Installation:**
Copy whichever `SKILL.md` you want into your Cursor rules folder, or run the automated script:
```bash
./scripts/install-plugin.sh cursor ~/path/to/your/project
```
This script maps the skills (e.g., `uncle-dev-code-review-and-quality`) into `.cursor/rules/` where Cursor will pick them up automatically for review contexts.

## Install for OpenCode

OpenCode uses an agent-driven skill execution environment configured through `AGENTS.md`.

**Global Installation:**
```bash
./scripts/install-opencode.sh --scope global
```
**Local Project Installation:**
```bash
./scripts/install-opencode.sh --scope local .
```
This populates `.config/opencode/` with the AGENTS system prompt file so the agent routes your commands automatically.

## Install for GitHub Copilot

Copilot reads agent personas from `.github/` directories.

**Installation:**
```bash
./scripts/install-plugin.sh copilot ~/path/to/your/project
```
This registers the Uncle Dev personas `@code-reviewer`, `@security-auditor`, and `@uncle-lead` into your repository so Copilot Chat can act as these senior engineers.

## Install for Gemini CLI

Install skills natively into Gemini CLI:

```bash
gemini skills install https://github.com/addyosmani/agent-skills.git --path skills
```

## Install for Other LLMs (Manual)

Uncle Dev skills are well-structured Markdown (`.md`) files. Copy the contents of any `SKILL.md` and paste it into your chat with ChatGPT, Claude Web, or any other agent to make it adopt the workflow.

## Install Graphify (Optional — Semantic Graph Search)

Graphify lets Uncle Dev skills use semantic graph traversal instead of grep for architecture research, dependency mapping, and impact analysis.

**Installation:**
```bash
# Install the graphify CLI
pip install graphifyy

# Build the knowledge graph (run from your project root)
graphify .
# Creates graphify-out/graph.json, GRAPH_REPORT.md, graph.html

# Keep it current after code changes (no LLM cost)
graphify update src/
```

Once `graphify-out/graph.json` exists, Uncle Dev skills activate graph-first search automatically at startup. No other configuration is needed.

## Verify it worked

Confirm the install for your tool:

- **Claude Code:** Run `/plugin` and confirm `uncle-dev` appears in the installed plugins list.
- **Codex / Cursor / OpenCode / Copilot / Gemini CLI (script installs):** Confirm the install script exits without errors, and check that the expected files exist in the target directory shown in each section above (for example, `.cursor/rules/` for Cursor, `.config/opencode/` for an OpenCode global install, `.github/` for Copilot, `.gemini/skills/` for Gemini CLI).
- **Gemini CLI:** Run `/skills list` and confirm the uncle-dev skills appear.
- **Graphify (optional):** Confirm `graphify-out/graph.json` exists after running `graphify .`.
