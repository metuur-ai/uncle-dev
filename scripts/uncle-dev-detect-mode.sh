#!/usr/bin/env bash
# uncle-dev-detect-mode.sh — single authoritative SDD-mode detection
#
# Usage: bash uncle-dev-detect-mode.sh
# Output: exactly "lid-ears" or "openspec" on stdout
#
# Precedence (R-5.11):
#   1. Explicit config value — `preferences.sdd_mode` via uncle-dev-config.sh.
#      When config is non-empty, return it immediately; filesystem is NOT checked.
#   2. Filesystem autodetect — when config is absent or empty:
#      lid-ears:  any of docs/ears/ docs/hld/ docs/lld/ docs/llds/ docs/specs/
#      openspec:  openspec/
#      Tie-breaking (both trees present, no config): prefer lid-ears to match
#      today's default (setup-project.sh previously created openspec/
#      unconditionally; its presence alone is not a reliable openspec signal).
#   3. Default: lid-ears — when neither config nor filesystem signals are present.
#
# Constraints:
#   - macOS bash 3.2 compatible (no declare -A, no mapfile, no ${var,,})
#   - Survives set -euo pipefail in callers (no unguarded grep)
#   - Distributable plugin: no personal paths, no hardcoded versions

set -euo pipefail

# ── Locate uncle-dev-config.sh (three-tier resolution) ───────────────────────
_scripts=""
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "${CLAUDE_PLUGIN_ROOT}/scripts/uncle-dev-config.sh" ]]; then
  _scripts="${CLAUDE_PLUGIN_ROOT}/scripts"
elif [[ -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/uncle-dev-config.sh" ]]; then
  _scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  _cache=$(ls -1d "${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/"*/ 2>/dev/null | sort -V | tail -1 || true)
  if [[ -n "$_cache" && -f "${_cache}scripts/uncle-dev-config.sh" ]]; then
    _scripts="${_cache}scripts"
  fi
fi

# ── Tier 1: config value ──────────────────────────────────────────────────────
_config_mode=""
if [[ -n "$_scripts" && -f "${_scripts}/uncle-dev-config.sh" ]]; then
  _config_mode=$(bash "${_scripts}/uncle-dev-config.sh" preferences.sdd_mode 2>/dev/null || true)
fi

# R-5.11: if config returns a non-empty value, use it immediately — no filesystem check
if [[ -n "$_config_mode" ]]; then
  printf '%s\n' "$_config_mode"
  exit 0
fi

# ── Tier 2: filesystem autodetect ────────────────────────────────────────────
_is_lid_ears=0
_is_openspec=0

# lid-ears signals: singular tree (docs/ears, docs/hld, docs/lld)
#                   plural tree   (docs/llds, docs/specs) — Finding B fix
for _dir in docs/ears docs/hld docs/lld docs/llds docs/specs; do
  if [[ -d "$_dir" ]]; then
    _is_lid_ears=1
    break
  fi
done

if [[ -d "openspec" ]]; then
  _is_openspec=1
fi

if [[ "$_is_lid_ears" -eq 1 ]]; then
  # lid-ears wins the tie when both trees are present (no config to break tie)
  printf 'lid-ears\n'
  exit 0
fi

if [[ "$_is_openspec" -eq 1 ]]; then
  printf 'openspec\n'
  exit 0
fi

# ── Tier 3: default ───────────────────────────────────────────────────────────
# R-5.3: default to lid-ears when neither config nor filesystem signals present
printf 'lid-ears\n'
