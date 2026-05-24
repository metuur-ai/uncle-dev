#!/usr/bin/env bash
# Canonical list of every installable asset in this repo.
# Source this file to get ASSET_* variables.
# Every installer must source this — adding an asset = one edit here.

# skills/ (32 dirs) — core engineering skill library
ASSET_SKILLS_ROOT="skills"

# .claude/skills/ (4 dirs) — OpenSpec lifecycle skills (apply/archive/explore/propose)
ASSET_SKILLS_OPENSPEC=".claude/skills"

# agents/ (6 .md) — reusable agent personas
ASSET_AGENTS="agents"

# .claude/commands/ top-level .md (19 files)
ASSET_COMMANDS_ROOT=".claude/commands"

# .claude/commands/opsx/ (4 .md) — opsx subcommands
ASSET_COMMANDS_OPSX=".claude/commands/opsx"

# hooks/ — session lifecycle hooks (*.sh + hooks.json + SIMPLIFY-IGNORE.md)
ASSET_HOOKS="hooks"

# scripts/ — project setup and utility scripts (setup-project.sh, install-*.sh, lib/)
ASSET_SCRIPTS="scripts"

# .claude-plugin/plugin.json — Claude Code plugin manifest
ASSET_PLUGIN_META=".claude-plugin/plugin.json"

# Rules files — coding principles and agent behavior guidance
ASSET_RULES=("AGENTS.md" "AGENT_RULES.md" "CLAUDE.md")
