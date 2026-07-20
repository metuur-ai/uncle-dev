#!/bin/bash
# openspec-guard — PreToolUse Edit|Write
# When editing inside openspec/changes/<id>/, validates:
# - Change ID matches the NNN-descriptive-slug format
# - All 5 required spec artifacts exist alongside the file being edited

set -euo pipefail

# shellcheck source=lib/hook-contract.sh
source "${BASH_SOURCE%/*}/lib/hook-contract.sh"

hook_read_input

REPO_ROOT="$(pwd)"
CFG_SCRIPT="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-config.sh"
[ -f "$CFG_SCRIPT" ] || CFG_SCRIPT="$REPO_ROOT/scripts/uncle-dev-config.sh"

# Honor hooks.openspec_guard toggle (R-2.7): exit 0 if disabled in project config.
[[ "$(bash "$CFG_SCRIPT" hooks.openspec_guard true 2>/dev/null || echo true)" == "false" ]] && exit 0

[ -z "$HOOK_FILE_PATH" ] && exit 0

# Only fire for files inside openspec/changes/
case "$HOOK_FILE_PATH" in
  *openspec/changes/*/*) ;;
  *) exit 0 ;;
esac

# Extract the change directory: everything up to and including the change ID segment
CHANGE_DIR=$(printf '%s' "$HOOK_FILE_PATH" | sed 's|\(.*openspec/changes/[^/]*\)/.*|\1|')
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
  hook_advise "openspec-guard [$CHANGE_ID]:${ISSUES}"
fi

exit 0
