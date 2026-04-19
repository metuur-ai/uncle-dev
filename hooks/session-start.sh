#!/bin/bash
# agent-skills session start hook
# Injects the using-agent-skills meta-skill into every new session

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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

  # Use jq to produce valid JSON (handles escaping of newlines and special chars)
  MSG="agent-skills loaded. Use the skill discovery flowchart to find the right skill for your task.

$CONTENT"
  jq -n --arg msg "$MSG" '{"priority": "IMPORTANT", "message": $msg}'
else
  echo '{"priority": "INFO", "message": "agent-skills: using-agent-skills meta-skill not found. Skills may still be available individually."}'
fi
