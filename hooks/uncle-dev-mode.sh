#!/bin/bash
# uncle-dev-mode — UserPromptSubmit (Claude-only)
#
# Lets a developer switch guard strictness mid-session WITHOUT editing
# .agents/uncle-dev-setup.yaml. When the prompt is `/uncle-dev-mode <profile>`,
# writes the chosen profile to a session-flag file that the config helper's
# override tier reads (see scripts/uncle-dev-config.sh). The two guards
# (spec-coherence-guard.sh, pre-commit-guard.sh) already resolve their
# execution_profile through that helper, so they honor the flag with no change.
#
# Flag file: ${CLAUDE_PROJECT_DIR:-$PWD}/.uncle-dev/session-mode (single line:
# strict|balanced|fast). Never touches the YAML (R-7.1, R-7.3).
#
# No-op for any prompt that is not `/uncle-dev-mode ...`.

set -uo pipefail

# Read the hook payload (UserPromptSubmit provides {"prompt": "..."} on stdin).
if [ -t 0 ]; then INPUT="{}"; else INPUT="$(cat)"; fi

PROMPT=""
if command -v jq >/dev/null 2>&1; then
  PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // .user_prompt // empty' 2>/dev/null)" || PROMPT=""
fi
# Fallback when jq is unavailable: crude extract of the prompt string value.
if [ -z "$PROMPT" ]; then
  PROMPT="$(printf '%s' "$INPUT" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
fi

# Only react to the /uncle-dev-mode command. Anything else is a silent no-op.
case "$PROMPT" in
  /uncle-dev-mode*) ;;
  *) exit 0 ;;
esac

# Parse the profile argument.
PROFILE="$(printf '%s' "$PROMPT" \
  | sed -n 's#^/uncle-dev-mode[[:space:]]\{1,\}\([a-z]\{1,\}\).*#\1#p')"

emit() {
  # Surface a confirmation/usage message to the session.
  local msg="$1" priority="${2:-INFO}"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg msg "$msg" --arg p "$priority" '{"priority": $p, "message": $msg}'
  else
    printf '%s\n' "$msg" >&2
  fi
}

case "$PROFILE" in
  strict|balanced|fast)
    PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
    FLAG_DIR="${PROJECT_DIR}/.uncle-dev"
    FLAG_FILE="${FLAG_DIR}/session-mode"
    if ! mkdir -p "$FLAG_DIR" 2>/dev/null; then
      emit "uncle-dev-mode: could not create ${FLAG_DIR} (read-only?). Mode unchanged." "IMPORTANT"
      exit 0
    fi
    printf '%s\n' "$PROFILE" > "$FLAG_FILE"
    emit "uncle-dev-mode: session strictness set to '${PROFILE}'. The spec-coherence and pre-commit guards now use this profile for the session (YAML unchanged). Clear with: rm ${FLAG_FILE#"$PWD"/}"
    ;;
  *)
    emit "uncle-dev-mode usage: /uncle-dev-mode <strict|balanced|fast>
  strict   — guards block on @spec orphans and commit-quality issues
  balanced — block on commit-quality, warn on @spec edits (default)
  fast     — advisory only; nothing blocks
Sets strictness for THIS session only; .agents/uncle-dev-setup.yaml is untouched." "IMPORTANT"
    ;;
esac

exit 0
