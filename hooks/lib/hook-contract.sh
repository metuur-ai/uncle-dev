#!/bin/bash
# hooks/lib/hook-contract.sh — Shared hook contract library
#
# Sourced by every hook that handles PreToolUse/PostToolUse/Stop events.
# Provides a single, canonical set of helpers for reading input and producing
# the correct Claude Code hook output/exit-code shapes.
#
# Claude Code hook contract (authoritative):
#   Input:  JSON on stdin — { "tool_name": "...", "tool_input": {...} }
#           (Stop/SubagentStop carry { "transcript_path": "...", "cwd": "..." } instead)
#   Block:  exit 2  + human-readable reason on stderr
#   PreToolUse/PostToolUse advisory:
#           exit 0  + {"hookSpecificOutput":{"additionalContext":"..."}} on stdout
#   Stop/SubagentStop advisory:
#           exit 0  + {"priority":"...","message":"..."} on stdout
#   Non-blocking error: exit 1  (stdout NOT shown to model — do not use for advisories)
#
# IMPORTANT — macOS compatibility:
#   All code here must run under /bin/bash 3.2 (macOS system bash).
#   Prohibited: associative arrays, mapfile/readarray, lowercase expansion (${v,,}).

# ---------------------------------------------------------------------------
# hook_read_input
#
# Reads the JSON hook payload from stdin exactly once into HOOK_INPUT,
# then exports HOOK_TOOL_NAME, HOOK_FILE_PATH, HOOK_COMMAND, HOOK_CONTENT,
# HOOK_NEW_STRING from the relevant JSON paths.
#
# Guard: if jq is not present, exits 0 silently (R-1.6).
# ---------------------------------------------------------------------------
hook_read_input() {
  command -v jq >/dev/null 2>&1 || exit 0

  if [ -t 0 ]; then
    HOOK_INPUT="{}"
  else
    HOOK_INPUT=$(cat)
  fi

  HOOK_TOOL_NAME=$(printf '%s' "$HOOK_INPUT" \
    | jq -r '.tool_name // empty' 2>/dev/null) || HOOK_TOOL_NAME=""
  HOOK_FILE_PATH=$(printf '%s' "$HOOK_INPUT" \
    | jq -r '.tool_input.file_path // empty' 2>/dev/null) || HOOK_FILE_PATH=""
  HOOK_COMMAND=$(printf '%s' "$HOOK_INPUT" \
    | jq -r '.tool_input.command // empty' 2>/dev/null) || HOOK_COMMAND=""
  HOOK_CONTENT=$(printf '%s' "$HOOK_INPUT" \
    | jq -r '.tool_input.content // empty' 2>/dev/null) || HOOK_CONTENT=""
  HOOK_NEW_STRING=$(printf '%s' "$HOOK_INPUT" \
    | jq -r '.tool_input.new_string // empty' 2>/dev/null) || HOOK_NEW_STRING=""

  export HOOK_INPUT HOOK_TOOL_NAME HOOK_FILE_PATH HOOK_COMMAND HOOK_CONTENT HOOK_NEW_STRING
}

# ---------------------------------------------------------------------------
# hook_block "reason"
#
# Blocks the tool call (PreToolUse contract): writes the human-readable reason
# to stderr and exits with code 2.
# ---------------------------------------------------------------------------
hook_block() {
  local reason="${1:-blocked by uncle-dev hook}"
  printf '%s\n' "$reason" >&2
  exit 2
}

# ---------------------------------------------------------------------------
# hook_allow
#
# Allows the tool call silently.
# ---------------------------------------------------------------------------
hook_allow() {
  exit 0
}

# ---------------------------------------------------------------------------
# hook_advise "message"
#
# For PreToolUse and PostToolUse hooks only.
# Emits {"hookSpecificOutput":{"additionalContext":"<message>"}} on stdout
# and exits 0 so the advisory reaches the model.
#
# Do NOT call this from Stop/SubagentStop hooks — use hook_advise_stop instead.
# ---------------------------------------------------------------------------
hook_advise() {
  local msg="${1:-}"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg m "$msg" \
      '{"hookSpecificOutput":{"additionalContext":$m}}'
  else
    # jq absent: print plain text to stderr so the message is not silently lost.
    printf 'ADVISORY: %s\n' "$msg" >&2
  fi
  exit 0
}

# ---------------------------------------------------------------------------
# hook_advise_stop "message" ["priority"]
#
# For Stop and SubagentStop hooks only.
# Emits {"priority":"<priority>","message":"<message>"} on stdout and exits 0.
# Default priority is "IMPORTANT".
# ---------------------------------------------------------------------------
hook_advise_stop() {
  local msg="${1:-}"
  local priority="${2:-IMPORTANT}"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg p "$priority" --arg m "$msg" \
      '{"priority":$p,"message":$m}'
  else
    printf 'ADVISORY [%s]: %s\n' "$priority" "$msg" >&2
  fi
  exit 0
}

# ---------------------------------------------------------------------------
# hook_require_project
#
# Safety valve for global hooks running in repositories that are not uncle-dev
# projects: if .agents/uncle-dev-setup.yaml does not exist in the directory
# resolved from PROJECT_DIR (or pwd when PROJECT_DIR is unset), exits 0
# silently — no stdout, no stderr, no filesystem side effects.
#
# R-1.14: must be fully transparent (zero output) when not in an uncle-dev repo.
# ---------------------------------------------------------------------------
hook_require_project() {
  local project_dir="${PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
  if [ ! -f "${project_dir}/.agents/uncle-dev-setup.yaml" ]; then
    exit 0
  fi
}
