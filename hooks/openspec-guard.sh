#!/bin/bash
# openspec-guard — PreToolUse Edit|Write
# When editing inside openspec/changes/<id>/, validates:
# - Change ID matches the NNN-descriptive-slug format
# - All 5 required spec artifacts exist alongside the file being edited

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

FILE_PATH="${CLAUDE_TOOL_INPUT_file_path:-}"
[ -z "$FILE_PATH" ] && exit 0

# Only fire for files inside openspec/changes/
case "$FILE_PATH" in
  *openspec/changes/*/*) ;;
  *) exit 0 ;;
esac

# Extract the change directory: everything up to and including the change ID segment
CHANGE_DIR=$(printf '%s' "$FILE_PATH" | sed 's|\(.*openspec/changes/[^/]*\)/.*|\1|')
CHANGE_ID=$(basename "$CHANGE_DIR")

ISSUES=""

# Validate change ID format: must be NNN-descriptive-slug (e.g. 001-auth-refactor)
if ! printf '%s' "$CHANGE_ID" | grep -qE '^[0-9]{3}-.+'; then
  ISSUES="${ISSUES}\n- Change ID \"$CHANGE_ID\" does not match required format: NNN-slug (e.g. 001-auth-refactor)"
fi

# Check all 5 required artifacts exist in the change directory
for artifact in proposal.md design.md tasks.md execution.md handoff.md; do
  if [ ! -f "$CHANGE_DIR/$artifact" ]; then
    ISSUES="${ISSUES}\n- Missing required artifact: $artifact"
  fi
done

if [ -n "$ISSUES" ]; then
  jq -n --arg id "$CHANGE_ID" --arg issues "$ISSUES" \
    '{"priority": "INFO", "message": ("openspec-guard [" + $id + "]:" + $issues)}'
fi

exit 0
