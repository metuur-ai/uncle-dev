#!/bin/bash
# pre-commit-guard — PreToolUse Bash
# Intercepts git commit commands. Validates message quality and scans staged diff
# for debug artifacts. Blocks the commit (exit 1) if issues are found.

set -euo pipefail

command -v jq  >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

# Read tool input from stdin
if [ -t 0 ]; then INPUT="{}"; else INPUT=$(cat); fi
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || COMMAND=""

# Only fire on git commit
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Extract commit message from -m flag (handles single and double quotes)
MSG=$(printf '%s' "$COMMAND" | sed -n "s/.*-m[[:space:]]*'\\([^']*\\)'.*/\\1/p")
if [ -z "$MSG" ]; then
  MSG=$(printf '%s' "$COMMAND" | sed -n 's/.*-m[[:space:]]*"\([^"]*\)".*/\1/p')
fi

ISSUES=""

# --- Message quality checks ---
if [ -n "$MSG" ]; then
  WORD_COUNT=$(printf '%s' "$MSG" | wc -w | tr -d ' ')
  if [ "$WORD_COUNT" -le 1 ]; then
    ISSUES="${ISSUES}\n- Message too short: \"$MSG\""
  elif printf '%s' "$MSG" | grep -qiE '^(fix|update|wip|test|temp|changes|misc|done|patch|commit|asdf|todo|stuff|edits?)\.?$'; then
    ISSUES="${ISSUES}\n- Placeholder message: \"$MSG\""
  fi
fi

# --- Staged diff checks (only inside a git repo) ---
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  DIFF=$(git diff --cached 2>/dev/null || true)
  if [ -n "$DIFF" ]; then
    printf '%s' "$DIFF" | grep -qE '^\+[^+].*console\.log\(' \
      && ISSUES="${ISSUES}\n- console.log() in staged changes"
    printf '%s' "$DIFF" | grep -qE '^\+[^+].*[^/]debugger;' \
      && ISSUES="${ISSUES}\n- debugger; in staged changes"
    printf '%s' "$DIFF" | grep -qE '^\+[^+].*(binding\.pry|pdb\.set_trace\(\))' \
      && ISSUES="${ISSUES}\n- Debug breakpoint in staged changes"
  fi
fi

if [ -n "$ISSUES" ]; then
  jq -n --arg msg "pre-commit-guard: review before committing:${ISSUES}\n\nFix these or confirm they are intentional before proceeding." \
    '{"priority": "IMPORTANT", "message": $msg}'
  exit 1
fi

exit 0
