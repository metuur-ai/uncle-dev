#!/bin/bash
# permission-notify — Notification event, matcher: permission_prompt
# Fires a desktop notification + terminal bell when Claude Code blocks waiting
# for the user to approve a tool execution. Opt out by setting UNCLE_DEV_NOTIFY=0.

set -euo pipefail

[ "${UNCLE_DEV_NOTIFY:-1}" = "0" ] && exit 0

if [ -t 0 ]; then INPUT="{}"; else INPUT=$(cat); fi

# Resolve project name (prefer hook cwd → CLAUDE_PROJECT_DIR → PWD; git toplevel if available).
HOOK_CWD=""
if command -v jq >/dev/null 2>&1; then
  HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
fi
PROJECT_DIR="${HOOK_CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}"
PROJECT_NAME=""
if [ -d "$PROJECT_DIR" ]; then
  GIT_TOP=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")
  if [ -n "$GIT_TOP" ]; then
    PROJECT_NAME=$(basename "$GIT_TOP")
  else
    PROJECT_NAME=$(basename "$PROJECT_DIR")
  fi
fi

# Pull the prompt message if Claude included one (truncate to keep banner tidy).
PROMPT_MSG=""
if command -v jq >/dev/null 2>&1; then
  PROMPT_MSG=$(printf '%s' "$INPUT" | jq -r '.message // empty' 2>/dev/null | head -c 180 || echo "")
fi

BASE_TITLE="${UNCLE_DEV_NOTIFY_TITLE:-Uncle Dev}"
if [ -n "$PROJECT_NAME" ]; then
  TITLE="$BASE_TITLE — $PROJECT_NAME"
else
  TITLE="$BASE_TITLE"
fi
SUBTITLE="Tool approval needed"
MESSAGE="${PROMPT_MSG:-Claude is waiting for permission to run a tool.}"

# Focus-bundle resolution (same logic as gate-notify.sh).
FOCUS_BUNDLE="${UNCLE_DEV_NOTIFY_FOCUS_BUNDLE:-${__CFBundleIdentifier:-}}"
if [ -z "$FOCUS_BUNDLE" ]; then
  case "${TERM_PROGRAM:-}" in
    Apple_Terminal) FOCUS_BUNDLE="com.apple.Terminal" ;;
    iTerm.app)      FOCUS_BUNDLE="com.googlecode.iterm2" ;;
    ghostty)        FOCUS_BUNDLE="com.mitchellh.ghostty" ;;
    WezTerm)        FOCUS_BUNDLE="com.github.wez.wezterm" ;;
    vscode)         FOCUS_BUNDLE="com.microsoft.VSCode" ;;
    WarpTerminal)   FOCUS_BUNDLE="dev.warp.Warp-Stable" ;;
  esac
fi

# Universal terminal bell — works in any terminal. Guard for non-TTY runs.
if [ -w /dev/tty ]; then
  { printf '\a' >/dev/tty; } 2>/dev/null || true
fi

case "${OSTYPE:-}" in
  darwin*)
    if command -v terminal-notifier >/dev/null 2>&1; then
      TN_ARGS=(
        -title "$TITLE"
        -subtitle "$SUBTITLE"
        -message "$MESSAGE"
        -sound "${UNCLE_DEV_NOTIFY_SOUND:-Glass}"
        -group "uncle-dev-permission"
      )
      if [ -n "$FOCUS_BUNDLE" ]; then
        TN_ARGS+=( -execute "open -b $FOCUS_BUNDLE" -sender "$FOCUS_BUNDLE" )
      fi
      terminal-notifier "${TN_ARGS[@]}" >/dev/null 2>&1 || true
    elif command -v osascript >/dev/null 2>&1; then
      osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" subtitle \"$SUBTITLE\" sound name \"${UNCLE_DEV_NOTIFY_SOUND:-Glass}\"" \
        >/dev/null 2>&1 || true
    fi
    ;;
  linux*)
    if command -v notify-send >/dev/null 2>&1; then
      notify-send --urgency=normal "$TITLE — $SUBTITLE" "$MESSAGE" >/dev/null 2>&1 || true
    fi
    ;;
esac

exit 0
