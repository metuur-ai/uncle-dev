#!/bin/bash
# pre-commit-guard — PreToolUse Bash
# Intercepts git commit commands. Validates message quality and scans staged diff
# for debug artifacts. Blocks the commit (exit 2 + stderr) if issues are found.

set -euo pipefail

# shellcheck source=lib/hook-contract.sh
source "${BASH_SOURCE%/*}/lib/hook-contract.sh"

hook_read_input

REPO_ROOT="$(pwd)"
CFG_SCRIPT="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-config.sh"
[ -f "$CFG_SCRIPT" ] || CFG_SCRIPT="$REPO_ROOT/scripts/uncle-dev-config.sh"

# Honor hooks.pre_commit toggle (R-2.5): exit 0 if disabled in project config.
[[ "$(bash "$CFG_SCRIPT" hooks.pre_commit true 2>/dev/null || echo true)" == "false" ]] && exit 0

command -v git >/dev/null 2>&1 || exit 0

EXEC_PROFILE="$(bash "$CFG_SCRIPT" preferences.execution_profile balanced 2>/dev/null || echo "balanced")"

# HOOK_COMMAND is populated by hook_read_input (stdin JSON)
COMMAND="$HOOK_COMMAND"

# Only fire on git commit
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Extract commit message from -m flag (handles single and double quotes).
# Note: heredoc style (-m "$(cat <<'EOF'...)") is not extracted here —
# the message quality check is skipped for heredoc commits (fragile extraction
# would produce false positives).
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
  elif printf '%s' "$MSG" | grep -qiE '^(fix|update|wip|test|temp|changes|misc|done|patch|commit|asdf|todo|stuff|edits?)\.?$' 2>/dev/null || true; then
    if printf '%s' "$MSG" | grep -qiE '^(fix|update|wip|test|temp|changes|misc|done|patch|commit|asdf|todo|stuff|edits?)\.?$' 2>/dev/null; then
      ISSUES="${ISSUES}\n- Placeholder message: \"$MSG\""
    fi
  fi
fi

# --- Staged diff checks (only inside a git repo) ---
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  DIFF=$(git diff --cached 2>/dev/null || true)
  if [ -n "$DIFF" ]; then
    if printf '%s' "$DIFF" | grep -qE '^\+[^+].*console\.log\(' 2>/dev/null; then
      ISSUES="${ISSUES}\n- console.log() in staged changes"
    fi
    if printf '%s' "$DIFF" | grep -qE '^\+[^+].*[^/]debugger;' 2>/dev/null; then
      ISSUES="${ISSUES}\n- debugger; in staged changes"
    fi
    if printf '%s' "$DIFF" | grep -qE '^\+[^+].*(binding\.pry|pdb\.set_trace\(\))' 2>/dev/null; then
      ISSUES="${ISSUES}\n- Debug breakpoint in staged changes"
    fi
  fi
fi

if [ -n "$ISSUES" ]; then
  if [ "$EXEC_PROFILE" = "strict" ] || [ "$EXEC_PROFILE" = "balanced" ]; then
    hook_block "pre-commit-guard: review before committing:${ISSUES}

Fix these or confirm they are intentional before proceeding."
  else
    hook_advise "pre-commit-guard (advisory):${ISSUES}

Execution profile is fast; commit not blocked."
  fi
fi

# --- SKILL.md lint (advisory, report-only) ---
# Opt-in: only fires in repos that author skills and carry the nori-lint rule
# config at scripts/nori-lint.config.json (not in end-user plugin installs).
if [ -f "$REPO_ROOT/scripts/nori-lint.config.json" ] && [ -f "$REPO_ROOT/scripts/lint-skills.sh" ] \
   && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  STAGED_SKILLS=$(git diff --cached --name-only 2>/dev/null | grep -E '(^|/)skills/[^/]+/SKILL\.md$' || true)
  if [ -n "$STAGED_SKILLS" ]; then
    LINT_OUT=$(bash "$REPO_ROOT/scripts/lint-skills.sh" --enforce $STAGED_SKILLS 2>/dev/null) || {
      SUMMARY=$(printf '%s\n' "$LINT_OUT" | tail -40)
      hook_advise "skill-lint (advisory): staged SKILL.md files have nori-lint violations:

${SUMMARY}

Report-only: commit not blocked. Run bash scripts/lint-skills.sh for the full report."
    }
  fi
fi

exit 0
