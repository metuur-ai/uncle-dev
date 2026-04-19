#!/bin/bash
# code-context pre-edit hook
# Reminds the agent to read AGENTS.md in the target directory before editing.
# Reads the file_path from the tool input passed via CLAUDE_TOOL_INPUT env var.

FILE_PATH="${CLAUDE_TOOL_INPUT_file_path:-}"

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

DIR="$(dirname "$FILE_PATH")"
AGENTS_MD="$DIR/AGENTS.md"

if [ -f "$AGENTS_MD" ]; then
  cat <<EOF
{
  "priority": "INFO",
  "message": "code-context: AGENTS.md exists for the directory you are about to edit.\nRead it before making changes: $AGENTS_MD"
}
EOF
fi
