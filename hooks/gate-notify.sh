#!/bin/bash
# gate-notify — Stop event
# Fires a desktop notification + terminal bell only when the assistant's last
# message ends at a known uncle-dev HARD GATE (spec-lock, plan-review, ack-gate,
# rollback-confirm, knowledge-capture mode select, research-question, etc.).
# Opt out by setting UNCLE_DEV_NOTIFY=0.

set -euo pipefail

[ "${UNCLE_DEV_NOTIFY:-1}" = "0" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

if [ -t 0 ]; then INPUT="{}"; else INPUT=$(cat); fi

TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
[ -z "$TRANSCRIPT_PATH" ] && exit 0
[ ! -r "$TRANSCRIPT_PATH" ] && exit 0

# Resolve project name: prefer cwd from the hook payload, then CLAUDE_PROJECT_DIR,
# then PWD. If the directory is a git repo, use the repo toplevel basename so the
# name matches what the user thinks of as "the project".
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
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

# Pull the last assistant text from the JSONL transcript (last ~200 events is
# plenty — Stop fires per-turn so the trailing assistant message is at the end).
LAST_MSG=$(tail -n 200 "$TRANSCRIPT_PATH" \
  | jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null \
  | tail -c 6000 || echo "")
[ -z "$LAST_MSG" ] && exit 0

# Gate detection — each entry is "pattern|||short-tag".
# Pattern is a fixed string (grep -F). Tag is shown in the notification subtitle.
GATES=(
  "Reply YES to lock|||Spec lock"
  "Do these specs look correct|||Spec lock"
  "Present the plan for human review|||Plan review"
  "BLOCKED: pending acknowledgements|||Acknowledgement needed"
  "Define the rollback plan|||Rollback confirm"
  "ready to research the codebase|||Research question"
  "Full or Lightweight mode|||Capture mode"
  "openspec validate|||OpenSpec validation"
)

MATCHED_TAG=""
for entry in "${GATES[@]}"; do
  pattern="${entry%%|||*}"
  tag="${entry##*|||}"
  if printf '%s' "$LAST_MSG" | grep -qF "$pattern"; then
    MATCHED_TAG="$tag"
    break
  fi
done
[ -z "$MATCHED_TAG" ] && exit 0

BASE_TITLE="${UNCLE_DEV_NOTIFY_TITLE:-Uncle Dev}"
if [ -n "$PROJECT_NAME" ]; then
  TITLE="$BASE_TITLE — $PROJECT_NAME"
else
  TITLE="$BASE_TITLE"
fi
MESSAGE="${UNCLE_DEV_NOTIFY_MESSAGE:-Hey, Uncle Dev needs your help!}"
SUBTITLE="$MATCHED_TAG"

# Resolve the host-terminal bundle ID so the notification's Show / click action
# focuses the terminal app Claude Code is running in. Resolution order:
#   1. UNCLE_DEV_NOTIFY_FOCUS_BUNDLE (explicit user override)
#   2. __CFBundleIdentifier  (Apple sets this when launching an app — survives subprocess spawns)
#   3. TERM_PROGRAM → known bundle ID mapping
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
        -group "uncle-dev-gate"
      )
      if [ -n "$FOCUS_BUNDLE" ]; then
        # -execute with `open -b` reliably focuses the terminal on click; the
        # built-in -activate path silently no-ops with unsigned terminal-notifier
        # builds on recent macOS. -sender swaps the notification icon.
        TN_ARGS+=( -execute "open -b $FOCUS_BUNDLE" -sender "$FOCUS_BUNDLE" )
      fi
      terminal-notifier "${TN_ARGS[@]}" >/dev/null 2>&1 || true
    elif command -v osascript >/dev/null 2>&1; then
      # osascript display notification can't customize the Show button — it
      # always focuses Script Editor. Install terminal-notifier
      # (brew install terminal-notifier) to get click-to-focus behavior.
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
