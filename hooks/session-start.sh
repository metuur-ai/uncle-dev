#!/bin/bash
# agent-skills session start hook
# Injects the using-agent-skills meta-skill into every new session
# R-10.6: exit 0 silently if not an uncle-dev project (no .agents/uncle-dev-setup.yaml).

command -v jq >/dev/null 2>&1 || exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# R-10.6: scope to uncle-dev projects only — transparent in unrelated repos.
# shellcheck source=lib/hook-contract.sh
source "${SCRIPT_DIR}/lib/hook-contract.sh"
hook_require_project

CFG_SCRIPT="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-config.sh"
[ -f "$CFG_SCRIPT" ] || CFG_SCRIPT="$SCRIPT_DIR/../scripts/uncle-dev-config.sh"

# Honor hooks.session_start toggle (R-2.10): exit 0 if disabled in project config.
# Run from PROJECT_DIR so uncle-dev-config.sh resolves .agents/ relative to project root.
[[ "$(cd "$PROJECT_DIR" && bash "$CFG_SCRIPT" hooks.session_start true 2>/dev/null || echo true)" == "false" ]] && exit 0

# R-10.7: clear .uncle-dev/session-mode at session start so mode strictness is not
# permanently sticky across unrelated sessions.  The mode command sets this file to
# override strictness for the current session only; a new session starts fresh.
SESSION_MODE_FILE="$PROJECT_DIR/.uncle-dev/session-mode"
if [ -f "$SESSION_MODE_FILE" ]; then
  python3 -c "import os; os.remove('${SESSION_MODE_FILE}')" 2>/dev/null || true
fi

SKILLS_DIR="$(dirname "$SCRIPT_DIR")/skills"
META_SKILL="$SKILLS_DIR/uncle-dev-using-agent-skills/SKILL.md"

if [ -f "$META_SKILL" ]; then
  # Extract only routing sections (Skill Discovery flowchart + Quick Reference table).
  # Core Operating Behaviors, Failure Modes, Skill Rules, and Lifecycle Sequence are
  # reference material — available in the full skill file when needed, not needed every turn.
  CONTENT=$(awk '
    /^## Skill Discovery/ { p=1 }
    /^## Quick Reference/ { p=1 }
    /^## / && !/^## Skill Discovery/ && !/^## Quick Reference/ { p=0 }
    p { print }
  ' "$META_SKILL")
  CONTENT="$CONTENT

Full skill: $META_SKILL"

  # Append recent learnings if .uncle-dev/learns/ exists in the project
  PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  LEARNS_DIR="$PROJECT_DIR/.uncle-dev/learns"
  if [ -d "$LEARNS_DIR" ]; then
    RECENT=$(find "$LEARNS_DIR" -name "*.md" -type f 2>/dev/null \
      | xargs ls -t 2>/dev/null \
      | head -3 \
      | xargs -I{} basename {} 2>/dev/null \
      | tr '\n' ', ' \
      | sed 's/, $//')
    if [ -n "$RECENT" ]; then
      CONTENT="$CONTENT

Recent learnings (.uncle-dev/learns/): $RECENT"
    fi
  fi

  # Surface the most recent uncle-dev-wrap handoff so the next session can resume.
  # Handoffs live in .devlocal/handoffs/ (gitignored personal scratchpad) and are
  # written by /uncle-dev-wrap. We list the newest file by mtime; the agent loads
  # it on demand via Read — we never paste the body into the session prompt.
  HANDOFFS_DIR="$PROJECT_DIR/.devlocal/handoffs"
  # Ensure the dir exists so /uncle-dev-wrap (and manual drops) always have a target.
  # Idempotent and cheap; failure (e.g. read-only fs) is non-fatal — skip silently.
  mkdir -p "$HANDOFFS_DIR" 2>/dev/null
  if [ -d "$HANDOFFS_DIR" ]; then
    LATEST_HANDOFF=$(find "$HANDOFFS_DIR" -maxdepth 1 -name "handoff-*.md" -type f 2>/dev/null \
      | xargs ls -t 2>/dev/null \
      | head -1)
    if [ -n "$LATEST_HANDOFF" ]; then
      # Strip the project prefix so the agent uses a relative path with Read
      REL_HANDOFF="${LATEST_HANDOFF#$PROJECT_DIR/}"
      CONTENT="$CONTENT

Recent handoff from /uncle-dev-wrap: $REL_HANDOFF
To resume, run: Read $REL_HANDOFF and continue from \"Next Session Focus\"."
    fi
  fi

  # Use jq to produce valid JSON (handles escaping of newlines and special chars)
  MSG="agent-skills loaded. Use the skill discovery flowchart to find the right skill for your task.

$CONTENT"
  jq -n --arg msg "$MSG" '{"priority": "IMPORTANT", "message": $msg}'
else
  echo '{"priority": "INFO", "message": "agent-skills: using-agent-skills meta-skill not found. Skills may still be available individually."}'
fi
