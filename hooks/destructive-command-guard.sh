#!/bin/bash
# destructive-command-guard — PreToolUse Bash
# Blocks dangerous shell and git commands before execution.
# Commands on the allowlist pass through silently — no confirmation needed.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

if [ -t 0 ]; then INPUT="{}"; else INPUT=$(cat); fi
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || COMMAND=""
[ -z "$COMMAND" ] && exit 0

# ── ALLOWLIST ─────────────────────────────────────────────────────────────────
# Commands that are always safe — read-only, non-destructive. Pass through silently.
# Based on tmp/destructive-commands.md "Safe commands" section.
case "$COMMAND" in
  # Safe git read-only commands
  "git status"|"git status "*) exit 0 ;;
  "git log"|"git log "*)       exit 0 ;;
  "git diff"|"git diff "*)     exit 0 ;;
  "git show"|"git show "*)     exit 0 ;;
  "git blame"*)                exit 0 ;;
  "git fetch"|"git fetch "*)   exit 0 ;;
  "git remote -v"|"git remote show"*|"git remote") exit 0 ;;
  # Branch listing only (not -D/-d delete)
  "git branch"|"git branch -v"|"git branch -a"|"git branch -r"|"git branch --list"*) exit 0 ;;
  # Common read-only shell commands
  ls*|cat\ *|head\ *|tail\ *|echo\ *|printf\ *|grep\ *|find\ *) exit 0 ;;
  which\ *|pwd|whoami|wc\ *|sort\ *|uniq\ *|cut\ *|awk\ *|sed\ *) exit 0 ;;
  # Build / test runners (non-destructive)
  npm\ test*|npm\ run\ test*|npm\ run\ build*|yarn\ test*|yarn\ build*) exit 0 ;;
  pytest*|python\ -m\ pytest*|go\ test*|cargo\ test*|make\ test*) exit 0 ;;
  # File read / navigation
  open\ *|pbcopy*|pbpaste*|bat\ *|less\ *|more\ *) exit 0 ;;
esac

MATCHED=""

# ── FILE DELETION ─────────────────────────────────────────────────────────────
case "$COMMAND" in
  *"rm -rf"*)  MATCHED="rm -rf (permanent recursive deletion)" ;;
  *"rm -r "*|*"rm -r"*) MATCHED="rm -r (recursive deletion)" ;;
  *"rm -f "*)  MATCHED="rm -f (forced deletion, skips confirmation)" ;;
  *" rm "*)    MATCHED="rm (file deletion)" ;;
  *"rmdir "*)  MATCHED="rmdir (directory removal)" ;;
  *"unlink "*)  MATCHED="unlink (file removal)" ;;
esac

# ── DESTRUCTIVE GIT ───────────────────────────────────────────────────────────
if [ -z "$MATCHED" ]; then
  case "$COMMAND" in
    *"git reset --hard"*)              MATCHED="git reset --hard (discards all uncommitted changes)" ;;
    *"git checkout -- "*|*"git checkout ."*) MATCHED="git checkout (overwrites uncommitted changes)" ;;
    *"git restore ."*|*"git restore --staged ."*) MATCHED="git restore (discards changes)" ;;
    *"git clean -f"*|*"git clean -fd"*) MATCHED="git clean -f (permanently deletes untracked files)" ;;
    *"git push --force"*|*"git push -f "*) MATCHED="git push --force (overwrites remote history — cannot be undone)" ;;
    *"git branch -D "*|*"git branch -d "*) MATCHED="git branch -d (deletes branch)" ;;
    *"git rebase"*)                    MATCHED="git rebase (rewrites commit history)" ;;
    *"git merge"*)                     MATCHED="git merge (modifies branch state)" ;;
    *"git stash drop"*|*"git stash clear"*) MATCHED="git stash drop/clear (discards stashed changes)" ;;
  esac
fi

# ── DESTRUCTIVE SQL ───────────────────────────────────────────────────────────
if [ -z "$MATCHED" ]; then
  case "$COMMAND" in
    *"DROP TABLE"*|*"drop table"*)     MATCHED="DROP TABLE (permanently destroys database table)" ;;
    *"DROP DATABASE"*|*"drop database"*) MATCHED="DROP DATABASE (destroys entire database)" ;;
    *"TRUNCATE"*|*"truncate table"*)   MATCHED="TRUNCATE (deletes all rows, cannot be rolled back)" ;;
  esac
  # DELETE FROM only dangerous without WHERE
  if [ -z "$MATCHED" ]; then
    case "$COMMAND" in
      *"DELETE FROM"*|*"delete from"*)
        case "$COMMAND" in
          *"WHERE"*|*"where"*) ;;  # Has WHERE clause — safe
          *) MATCHED="DELETE FROM without WHERE (deletes all rows)" ;;
        esac ;;
    esac
  fi
fi

# ── DESTRUCTIVE MONGODB ────────────────────────────────────────────────────────
if [ -z "$MATCHED" ]; then
  case "$COMMAND" in
    # Database / collection destruction
    *"dropDatabase()"*|*"dropDatabase ()"*) MATCHED="db.dropDatabase() (destroys entire MongoDB database)" ;;
    *".drop()"*|*".drop ()"*)               MATCHED="collection.drop() (permanently destroys MongoDB collection)" ;;
    # deleteMany without a filter object — {} means all documents
    *"deleteMany({})"*|*"deleteMany( {})"*|*"deleteMany({ })"*) MATCHED="deleteMany({}) (deletes all documents in collection)" ;;
    # remove() without filter — legacy but still used
    *".remove({})"*|*".remove( {})"*|*".remove({ })"*)          MATCHED="collection.remove({}) (deletes all documents)" ;;
    # findOneAndDelete can be destructive at scale in scripts
    *"findOneAndDelete({})"*)               MATCHED="findOneAndDelete({}) (deletes documents — no filter)" ;;
    # mongosh / mongo CLI eval with destructive ops
    *"mongosh"*"dropDatabase"*|*"mongo"*"dropDatabase"*) MATCHED="mongosh dropDatabase() (destroys MongoDB database via CLI)" ;;
    *"mongosh"*".drop()"*|*"mongo"*".drop()"*)           MATCHED="mongosh collection.drop() (destroys MongoDB collection via CLI)" ;;
  esac
fi

if [ -n "$MATCHED" ]; then
  jq -n --arg cmd "$COMMAND" --arg matched "$MATCHED" \
    '{"priority": "IMPORTANT", "message": ("destructive-command-guard: \($matched) requires explicit confirmation.\n\nExplain to the user what this will do and wait for a clear \"yes\" before running:\n  " + $cmd)}'
  exit 1
fi

exit 0
