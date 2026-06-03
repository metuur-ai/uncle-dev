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

Codex installs Uncle Dev as a native local plugin assembled from the shared source directories in this repository.

**User Installation:**
```bash
./scripts/install-codex.sh
```

**Local Project Installation:**
```bash
./scripts/install-codex.sh --scope local .
```

This assembles `plugins/uncle-dev/` from the repo's shared `skills/` and `agents/` directories and registers it via `.agents/plugins/marketplace.json` in the selected install root.

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
