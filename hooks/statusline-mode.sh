#!/bin/bash
# statusline-mode — uncle-dev session-mode badge (Claude-only, optional)
#
# Prints the active session-strictness badge, e.g. [UNCLE-DEV:STRICT], read from
# the session-mode flag written by /uncle-dev-mode (hooks/uncle-dev-mode.sh).
# Prints NOTHING when no flag is set, so it is safe to splice into an existing
# statusline command without changing its output when the mode is unset.
#
# Integration (does NOT hijack an existing statusline): append this script's
# output to your statusLine command in .claude/settings.json, e.g.
#   "statusLine": {
#     "type": "command",
#     "command": "your-existing-statusline; bash ${CLAUDE_PLUGIN_ROOT}/hooks/statusline-mode.sh"
#   }
# It reads the flag at ${CLAUDE_PROJECT_DIR:-$PWD}/.uncle-dev/session-mode.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
FLAG_FILE="${PROJECT_DIR}/.uncle-dev/session-mode"

[ -f "$FLAG_FILE" ] || exit 0

MODE="$(head -n1 "$FLAG_FILE" 2>/dev/null | tr -d '[:space:]')"
case "$MODE" in
  strict|balanced|fast)
    printf '[UNCLE-DEV:%s]' "$(printf '%s' "$MODE" | tr '[:lower:]' '[:upper:]')"
    ;;
  *) exit 0 ;;
esac
