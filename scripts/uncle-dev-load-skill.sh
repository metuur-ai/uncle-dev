#!/usr/bin/env bash
# uncle-dev-load-skill.sh — resolve the active skill and any companions for a base skill name.
#
# Usage:
#   bash uncle-dev-load-skill.sh <base-skill-name>
#
# Example:
#   bash uncle-dev-load-skill.sh uncle-dev-test-driven-development
#
# Output on stdout (deterministic, one per line):
#   SKILL: <ref>              ← exactly one
#   COMPANION: <path>         ← zero or more
#
# <ref> is either `uncle-dev:<base>` (no override) or a project-relative
# file path (override registered in skills.overrides.<base>.path).
#
# Stderr:
#   ERROR: unknown skill '<name>'       ← emitted when base has no skills/<name>/ dir;
#                                         exit is non-zero (fail-closed for unknown names).
#   WARN: missing skill file <path>     ← emitted if a registered path doesn't exist
#                                         on disk; the line is omitted from stdout
#                                         and the loader falls back to the base id.
#
# Exit: 0 for known skill names (even when config is absent).
#       Non-zero for unknown skill names (fail-closed validation).
#
# Contract: this loader NEVER opens .agents/uncle-dev-setup.yaml directly.
# All config reads go through scripts/uncle-dev-config.sh — the single source of
# truth for config semantics, validation, and schema migrations.

set -euo pipefail

BASE="${1:-}"

if [[ -z "${BASE}" ]]; then
  echo "Usage: uncle-dev-load-skill.sh <base-skill-name>" >&2
  exit 1
fi

# Resolve the plugin root. Resolution order:
#   1. ${CLAUDE_PLUGIN_ROOT} — set by Claude Code for installed plugins.
#   2. Script's own grandparent dir (BASH_SOURCE/../..) — repo-local checkout.
# This is used both for skill-dir validation and for locating config.sh.
_this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  plugin_root="${CLAUDE_PLUGIN_ROOT}"
else
  plugin_root="$(cd "${_this_dir}/.." && pwd)"
fi

# Fail-closed: unknown skill name → error to stderr + non-zero exit.
# Fail-open only for missing config/overrides (absence of customization is normal).
if [[ ! -d "${plugin_root}/skills/${BASE}" ]]; then
  echo "ERROR: unknown skill '${BASE}'" >&2
  exit 1
fi

# Locate uncle-dev-config.sh. Resolution order:
#   1. ${plugin_root}/scripts — covers both CLAUDE_PLUGIN_ROOT and repo checkout.
#   2. ~/.claude/plugins cache — newest versioned copy (sort -V | tail -1).
_cfg="${plugin_root}/scripts/uncle-dev-config.sh"
if [[ ! -f "${_cfg}" ]]; then
  _cache_dir=$(ls -1d "${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev"/*/ 2>/dev/null | sort -V | tail -1)
  if [[ -n "${_cache_dir}" ]]; then
    _cfg="${_cache_dir}scripts/uncle-dev-config.sh"
  fi
fi

# If we can't find the config helper, fall back to the bundled base skill.
# This keeps invoking commands working in environments where the plugin
# isn't installed (e.g., this repo's own development sessions).
if [[ ! -f "${_cfg}" ]]; then
  echo "SKILL: uncle-dev:${BASE}"
  exit 0
fi

OVERRIDE_PATH="$(bash "${_cfg}" "skills.overrides.${BASE}.path" "" 2>/dev/null || true)"

# Emit the active SKILL: line.
if [[ -n "${OVERRIDE_PATH}" ]]; then
  if [[ -f "${OVERRIDE_PATH}" ]]; then
    echo "SKILL: ${OVERRIDE_PATH}"
  else
    echo "WARN: missing skill file ${OVERRIDE_PATH}" >&2
    echo "SKILL: uncle-dev:${BASE}"
  fi
else
  echo "SKILL: uncle-dev:${BASE}"
fi

# Emit COMPANION: lines, one per registered companion whose file exists.
while IFS= read -r companion_path; do
  if [[ -z "${companion_path}" ]]; then
    continue
  fi
  if [[ -f "${companion_path}" ]]; then
    echo "COMPANION: ${companion_path}"
  else
    echo "WARN: missing skill file ${companion_path}" >&2
  fi
done < <(bash "${_cfg}" --list "skills.companions.${BASE}" path 2>/dev/null || true)
