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
# <ref> is either `agent-skills:<base>` (no override) or a project-relative
# file path (override registered in skills.overrides.<base>.path).
#
# Stderr:
#   WARN: missing skill file <path>     ← emitted if a registered path doesn't exist
#                                         on disk; the line is omitted from stdout
#                                         and the loader falls back to the base id.
#
# Exit: 0 (callers should not fail on missing config; absence of customization is
#         the common case and yields a single SKILL: line for the base skill).
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

# Locate uncle-dev-config.sh. Resolution order:
#   1. ${CLAUDE_PLUGIN_ROOT}/scripts — set by Claude Code in production.
#   2. local ./scripts — agent-skills repo dev sessions and smoke tests.
#   3. ~/.claude/plugins cache — fallback when the helper isn't colocated.
# Local takes precedence over the cache so dev sessions never pick up
# a stale installed copy of the helper.
_cfg="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-config.sh"
if [[ ! -f "${_cfg}" ]] && [[ -f "scripts/uncle-dev-config.sh" ]]; then
  _cfg="scripts/uncle-dev-config.sh"
fi
if [[ ! -f "${_cfg}" ]]; then
  _cfg="$(find "${HOME}/.claude/plugins" -name "uncle-dev-config.sh" 2>/dev/null | head -1)"
fi

# If we can't find the config helper, fall back to the bundled base skill.
# This keeps invoking commands working in environments where the plugin
# isn't installed (e.g., this repo's own development sessions).
if [[ ! -f "${_cfg}" ]]; then
  echo "SKILL: agent-skills:${BASE}"
  exit 0
fi

OVERRIDE_PATH="$(bash "${_cfg}" "skills.overrides.${BASE}.path" "" 2>/dev/null || true)"

# Emit the active SKILL: line.
if [[ -n "${OVERRIDE_PATH}" ]]; then
  if [[ -f "${OVERRIDE_PATH}" ]]; then
    echo "SKILL: ${OVERRIDE_PATH}"
  else
    echo "WARN: missing skill file ${OVERRIDE_PATH}" >&2
    echo "SKILL: agent-skills:${BASE}"
  fi
else
  echo "SKILL: agent-skills:${BASE}"
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
