# 2. Uncle Dev Installation Guide

Uncle Dev is modular and can be installed into a variety of popular AI coding tools. This guide details how developers can set up these skills.

## Claude Code (Recommended)
Claude Code is a CLI agent that supports robust plugins.

**Via Marketplace:**
```bash
/plugin install uncle-dev@uncle-dev-agent-skills
```

**Local/Development Install (from cloned repo):**
```bash
git clone https://github.com/addyosmani/agent-skills.git
claude --plugin-dir /path/to/agent-skills
```

## Cursor
Cursor IDE reads instruction rules from the `.cursor/rules/` directory.

**Installation:**
You can manually copy whichever `SKILL.md` you want to use into your Cursor rules folder, or use the automated script:
```bash
./scripts/install-plugin.sh cursor ~/path/to/your/project
```
This script maps the skills (e.g., `uncle-dev-code-review-and-quality`) into `.cursor/rules/` where Cursor will pick them up automatically for review contexts.

## OpenCode
OpenCode uses an AI-agent-driven skill execution environment via an `AGENTS.md` configuration.

**Global Installation:**
```bash
./scripts/install-opencode.sh --scope global
```
**Local Project Installation:**
```bash
./scripts/install-opencode.sh --scope local .
```
This populates `.config/opencode/` with the AGENTS system prompting file, ensuring the agent routes your commands seamlessly.

## GitHub Copilot
Copilot reads agent personas from `.github/` directories.

**Installation:**
```bash
./scripts/install-plugin.sh copilot ~/path/to/your/project
```
This registers the Uncle Dev personas like `@uncle-dev-ag-code-reviewer` and `@uncle-dev-ag-security-auditor` into your repositories so that Copilot Chat can roleplay as these senior engineers.

## Gemini CLI
You can natively install skills to your Gemini CLI.
```bash
gemini skills install https://github.com/addyosmani/agent-skills.git --path skills
```

## Manual / Other LLMs
Because Uncle Dev skills are just well-structured Markdown (`.md`) files, you can copy the contents of any `SKILL.md` and paste it directly into your chat with ChatGPT, Claude Web, or any other agent to force them to adopt the specified workflow!
