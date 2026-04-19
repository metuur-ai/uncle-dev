#!/bin/bash
# knowledge-capture-nudge — PostToolUse Bash
# After a test or build command succeeds, nudges once per cooldown window to
# capture knowledge while context is fresh.
# Uses a timestamp file to avoid repeating more than once per hour.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

if [ -t 0 ]; then INPUT="{}"; else INPUT=$(cat); fi

# Extract bash command output — try multiple paths (Claude Code PostToolUse structure)
OUTPUT=$(printf '%s' "$INPUT" | jq -r '
  if .tool_response then
    if (.tool_response | type) == "string" then .tool_response
    elif .tool_response.stdout then .tool_response.stdout
    else ""
    end
  elif .output then .output
  else ""
  end
' 2>/dev/null) || OUTPUT=""
[ -z "$OUTPUT" ] && exit 0

# Check for test/build success signals
case "$OUTPUT" in
  *"PASS"*|*" passed"*|*"✓"*|*"✔"*|*"All tests"*|\
  *"Build succeeded"*|*"build succeeded"*|*"successfully built"*|\
  *"0 failed"*|*"no failures"*) ;;
  *) exit 0 ;;
esac

# Cooldown: fire at most once per hour using a timestamp file
NUDGE_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.knowledge-capture-nudged"
if [ -f "$NUDGE_FILE" ]; then
  # Skip if nudged within the last 60 minutes
  if [ -n "$(find "$NUDGE_FILE" -mmin -60 2>/dev/null)" ]; then
    exit 0
  fi
fi
touch "$NUDGE_FILE" 2>/dev/null || true

jq -n '{"priority": "INFO", "message": "Tests passed. If this resolved a problem you have been working on, run /uncle-dev-knowledge-capture while the context is fresh."}'

exit 0
