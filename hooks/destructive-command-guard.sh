#!/bin/bash
# destructive-command-guard — PreToolUse Bash
# Blocks dangerous shell and git commands before execution.
# Commands on the allowlist pass through silently — no confirmation needed.
#
# R-1.4: chained commands (;, &&, ||, |, $(), backticks) are split into segments;
#         each segment is evaluated independently.
# R-1.5: allowlist patterns are anchored to the full token (not prefix-glob).

set -euo pipefail

# shellcheck source=lib/hook-contract.sh
source "${BASH_SOURCE%/*}/lib/hook-contract.sh"

hook_read_input

REPO_ROOT="$(pwd)"
CFG_SCRIPT="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-config.sh"
[ -f "$CFG_SCRIPT" ] || CFG_SCRIPT="$REPO_ROOT/scripts/uncle-dev-config.sh"

# Honor hooks.destructive_command_guard toggle (R-2.8): exit 0 if disabled.
# Note: this hook is intentionally global (fires in all repos), but the toggle
# in the project config provides the opt-out when the guard is not wanted.
[[ "$(bash "$CFG_SCRIPT" hooks.destructive_command_guard true 2>/dev/null || echo true)" == "false" ]] && exit 0

COMMAND="$HOOK_COMMAND"
[ -z "$COMMAND" ] && exit 0

# ---------------------------------------------------------------------------
# split_segments: split a command string on shell chain operators and
# command-substitution boundaries so each sub-command can be evaluated
# independently.  Prints one segment per line (may still contain spaces).
#
# Handles: ; && || | $( `...`
#
# Implementation note (macOS bash 3.2 + macOS sed):
#   macOS sed does NOT expand \n in replacement strings (GNU-only).
#   We use a two-step approach:
#     1. Normalize multi-char operators (&&, ||, $() ) to a delimiter char.
#     2. Use `tr` to convert single-char delimiters to newlines.
#   We pick ASCII unit-separator (octal \037) as an intermediate delimiter
#   because it cannot appear in shell commands.
# ---------------------------------------------------------------------------
split_segments() {
  local cmd="$1"
  # Normalize multi-char operators to the unit-separator char (oct 037 = 0x1F)
  # using a Python one-liner (python3 is available on macOS 10.15+).
  # Falls back to the original string (no split) if python3 is absent —
  # still checked against the full-command patterns below.
  local normalized
  if command -v python3 >/dev/null 2>&1; then
    normalized=$(python3 -c "
import sys, re
cmd = sys.argv[1]
# Replace &&, ||, and \$( with the unit-separator (U+001F)
cmd = re.sub(r'&&|\|\||;\s*|\||\\\$\(|\`', '\x1f', cmd)
sys.stdout.write(cmd)
" "$cmd" 2>/dev/null) || normalized="$cmd"
  else
    normalized="$cmd"
  fi
  # Use tr to convert the unit-separator to newlines; also split on semicolon.
  # Use printf '%s\n' (with trailing newline) so while-read processes the last segment.
  printf '%s\n' "$normalized" | tr '\037;' '\n\n' | while IFS= read -r seg; do
    # Strip leading/trailing whitespace
    seg="${seg#"${seg%%[! ]*}"}"
    seg="${seg%"${seg##*[! ]}"}"
    [ -n "$seg" ] && printf '%s\n' "$seg"
  done
}

# ---------------------------------------------------------------------------
# is_allowlisted: returns 0 (true) if a single segment is on the safe list.
# All patterns are anchored: either exact match or "cmd " prefix match.
# ---------------------------------------------------------------------------
is_allowlisted() {
  local seg="$1"
  case "$seg" in
    # Safe git read-only commands (exact or cmd+space prefix)
    "git status"|"git status "*)  return 0 ;;
    "git log"|"git log "*)        return 0 ;;
    "git diff"|"git diff "*)      return 0 ;;
    "git show"|"git show "*)      return 0 ;;
    "git blame"|"git blame "*)    return 0 ;;
    "git fetch"|"git fetch "*)    return 0 ;;
    "git remote -v"|"git remote show"*|"git remote") return 0 ;;
    # Branch listing only (not -D/-d delete)
    "git branch"|"git branch -v"|"git branch -a"|"git branch -r"|"git branch --list"*) return 0 ;;
    # Safe shell read-only commands (exact or "cmd " prefix — NOT bare prefix glob)
    "ls"|"ls "*)     return 0 ;;
    "cat "*)         return 0 ;;
    "head "*)        return 0 ;;
    "tail "*)        return 0 ;;
    "echo "*)        return 0 ;;
    "printf "*)      return 0 ;;
    "grep "*)        return 0 ;;
    "find "*)        return 0 ;;
    "which "*)       return 0 ;;
    "pwd")           return 0 ;;
    "whoami")        return 0 ;;
    "wc "*)          return 0 ;;
    "sort "*)        return 0 ;;
    "uniq "*)        return 0 ;;
    "cut "*)         return 0 ;;
    "awk "*)         return 0 ;;
    # sed is safe only when NOT -i (in-place edit is destructive).
    "sed "*)
      case "$seg" in
        "sed -i"*) return 1 ;;
        *)         return 0 ;;
      esac ;;
    # Build / test runners (non-destructive)
    "npm test"*|"npm run test"*|"npm run build"*) return 0 ;;
    "yarn test"*|"yarn build"*) return 0 ;;
    "pytest"*|"python -m pytest"*) return 0 ;;
    "go test"*|"cargo test"*|"make test"*) return 0 ;;
    # File read / navigation
    "open "*)    return 0 ;;
    "pbcopy"*)   return 0 ;;
    "pbpaste"*)  return 0 ;;
    "bat "*)     return 0 ;;
    "less "*)    return 0 ;;
    "more "*)    return 0 ;;
    # Common safe utilities
    "jq "*)      return 0 ;;
    "rtk "*)     return 0 ;;
    "true"|"false"|"exit "*|"echo"|"pwd"|"whoami") return 0 ;;
  esac
  return 1
}

# ---------------------------------------------------------------------------
# check_segment: check one command segment for destructive patterns.
# Sets MATCHED to a description and returns 1 if destructive; 0 if safe.
# ---------------------------------------------------------------------------
MATCHED=""

check_segment() {
  local seg="$1"

  # Allow if explicitly on the safe list
  is_allowlisted "$seg" && return 0

  # ── FILE DELETION ──────────────────────────────────────────────────────────
  case "$seg" in
    *"rm -rf"*)             MATCHED="rm -rf (permanent recursive deletion)"; return 1 ;;
    *"rm -r "*|*"rm -r")   MATCHED="rm -r (recursive deletion)"; return 1 ;;
    *"rm -f "*)             MATCHED="rm -f (forced deletion, skips confirmation)"; return 1 ;;
    "rm "*)                 MATCHED="rm (file deletion)"; return 1 ;;
    *" rm "*)               MATCHED="rm (file deletion)"; return 1 ;;
    *"rmdir "*)             MATCHED="rmdir (directory removal)"; return 1 ;;
    *"unlink "*)            MATCHED="unlink (file removal)"; return 1 ;;
  esac

  # ── DESTRUCTIVE GIT ────────────────────────────────────────────────────────
  case "$seg" in
    *"git reset --hard"*)              MATCHED="git reset --hard (discards all uncommitted changes)"; return 1 ;;
    *"git checkout -- "*|*"git checkout ."*) MATCHED="git checkout (overwrites uncommitted changes)"; return 1 ;;
    *"git restore ."*|*"git restore --staged ."*) MATCHED="git restore (discards changes)"; return 1 ;;
    *"git clean -f"*|*"git clean -fd"*) MATCHED="git clean -f (permanently deletes untracked files)"; return 1 ;;
    *"git push --force"*|*"git push -f "*) MATCHED="git push --force (overwrites remote history — cannot be undone)"; return 1 ;;
    *"git branch -D "*|*"git branch -d "*) MATCHED="git branch -d (deletes branch)"; return 1 ;;
    *"git rebase"*)                    MATCHED="git rebase (rewrites commit history)"; return 1 ;;
    *"git merge"*)                     MATCHED="git merge (modifies branch state)"; return 1 ;;
    *"git stash drop"*|*"git stash clear"*) MATCHED="git stash drop/clear (discards stashed changes)"; return 1 ;;
  esac

  # ── DESTRUCTIVE SQL ────────────────────────────────────────────────────────
  case "$seg" in
    *"DROP TABLE"*|*"drop table"*)     MATCHED="DROP TABLE (permanently destroys database table)"; return 1 ;;
    *"DROP DATABASE"*|*"drop database"*) MATCHED="DROP DATABASE (destroys entire database)"; return 1 ;;
    *"TRUNCATE"*|*"truncate table"*)   MATCHED="TRUNCATE (deletes all rows, cannot be rolled back)"; return 1 ;;
    *"DELETE FROM"*|*"delete from"*)
      case "$seg" in
        *"WHERE"*|*"where"*) ;;  # Has WHERE clause — safe
        *) MATCHED="DELETE FROM without WHERE (deletes all rows)"; return 1 ;;
      esac ;;
  esac

  # ── DESTRUCTIVE MONGODB ────────────────────────────────────────────────────
  case "$seg" in
    *"dropDatabase()"*|*"dropDatabase ()"*) MATCHED="db.dropDatabase() (destroys entire MongoDB database)"; return 1 ;;
    *".drop()"*|*".drop ()"*)               MATCHED="collection.drop() (permanently destroys MongoDB collection)"; return 1 ;;
    *"deleteMany({})"*|*"deleteMany( {})"*|*"deleteMany({ })"*) MATCHED="deleteMany({}) (deletes all documents in collection)"; return 1 ;;
    *".remove({})"*|*".remove( {})"*|*".remove({ })"*)          MATCHED="collection.remove({}) (deletes all documents)"; return 1 ;;
    *"findOneAndDelete({})"*)               MATCHED="findOneAndDelete({}) (deletes documents — no filter)"; return 1 ;;
    *"mongosh"*"dropDatabase"*|*"mongo"*"dropDatabase"*) MATCHED="mongosh dropDatabase() (destroys MongoDB database via CLI)"; return 1 ;;
    *"mongosh"*".drop()"*|*"mongo"*".drop()"*) MATCHED="mongosh collection.drop() (destroys MongoDB collection via CLI)"; return 1 ;;
  esac

  return 0
}

# ---------------------------------------------------------------------------
# Main: split COMMAND into segments and check each one independently (R-1.4).
# The first destructive segment found blocks the entire command.
# ---------------------------------------------------------------------------

FULL_COMMAND="$COMMAND"

# Process each segment from split_segments in a while-read loop.
# We store to a temp file to avoid subshell variable scoping issues.
SEGMENTS_FILE=$(mktemp)
split_segments "$FULL_COMMAND" > "$SEGMENTS_FILE" 2>/dev/null || true

while IFS= read -r segment; do
  [ -z "$segment" ] && continue
  MATCHED=""
  if ! check_segment "$segment"; then
    rm -f "$SEGMENTS_FILE"
    hook_block "destructive-command-guard: ${MATCHED} requires explicit confirmation.

Explain to the user what this will do and wait for a clear \"yes\" before running:
  $FULL_COMMAND"
  fi
done < "$SEGMENTS_FILE"

rm -f "$SEGMENTS_FILE"
exit 0
