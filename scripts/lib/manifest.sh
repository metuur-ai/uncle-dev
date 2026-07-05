#!/usr/bin/env bash
# Canonical list of every installable asset in this repo.
# Source this file to get ASSET_* variables.
# Every installer must source this — adding an asset = one edit here.

# skills/ — full skill library (engineering skills + OpenSpec lifecycle + docs skills)
ASSET_SKILLS_ROOT="skills"

# agents/ (9 .md) — reusable agent personas
ASSET_AGENTS="agents"

# commands/ — slash commands
ASSET_COMMANDS_ROOT="commands"

# hooks/ — session lifecycle hooks (*.sh + hooks.json + SIMPLIFY-IGNORE.md)
ASSET_HOOKS="hooks"

# scripts/ — project setup and utility scripts (setup-project.sh, install-*.sh, lib/)
ASSET_SCRIPTS="scripts"

# Codex-only agent manifests that are copied into the bundled skill trees
# during install-codex.sh. Keeping them under the plugin namespace avoids
# polluting the shared skills/ directory with Codex-specific metadata.
ASSET_CODEX_AGENT_MANIFESTS="plugins/uncle-dev/agent-manifests"

# .claude-plugin/plugin.json — Claude Code plugin manifest
ASSET_PLUGIN_META=".claude-plugin/plugin.json"

# Rules files — coding principles and agent behavior guidance
ASSET_RULES=("AGENTS.md" "AGENT_RULES.md" "CLAUDE.md")
